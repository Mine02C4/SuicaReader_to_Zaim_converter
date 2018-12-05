require 'csv'
require 'date'

buses = {
  "京急バス" => "京浜急行バス",
  "伊豆箱根バス" => "伊豆箱根バス",
  "東急バス" => "東急バス",
}

def conv_content(text)
  in_and_out = text.split("\n")
  in_match_station = in_and_out[0].match(/ (\S*)（/)[1]
  in_match_shop = in_and_out[0].match(/ (\S*)）/)[1]
  out_match_station = in_and_out[1].match(/ (\S*)（/)[1]
  out_match_shop = in_and_out[1].match(/ (\S*)）/)[1]
  shop = in_match_shop + " " + out_match_shop
  if in_match_shop == out_match_shop then
    shop = in_match_shop
  end
  return [
    shop,
    in_match_station + "から" + out_match_station
  ]
end

def get_last_no
  csvlist = Dir.glob("*.csv")
  pasmologs = csvlist.select {|item|
    /^PASMO [0-9]{8}-[0-9]{8}\.csv$/.match(item) ||
    /^PASMO [0-9]{8}-[0-9]{8} L[0-9]+\.csv$/.match(item)
  }
  lastlog = pasmologs.sort {|a, b|
    regex = /PASMO [0-9]{8}-([0-9]{8})/
    regex.match(b).captures[0].to_i <=> regex.match(a).captures[0].to_i
  }[0]
  if /^PASMO [0-9]{8}-[0-9]{8}\.csv$/.match lastlog then
    return CSV.read(lastlog, encoding: Encoding::SJIS).collect { |row|
      row[0].to_i
    }.sort {|a, b| b <=> a }.first
  else
    regex = /PASMO [0-9]{8}-[0-9]{8} L([0-9]+)/
    last_no = regex.match(lastlog).captures[0].to_i
    return last_no
  end
end

if ARGV.size == 1 then
  last_no = get_last_no
  csv_data = CSV.read(ARGV[0], encoding: "UTF-8", headers: true)
  b_date = nil
  e_date = nil
  max_no = 0
  out_csv = CSV.generate(encoding: Encoding::SJIS) do |csv|
    csv << [
      "日付", "方法",
      "カテゴリ", "カテゴリの内訳",
      "支払元", "入金先",
      "品目", "メモ", "お店",
      "通貨", "収入", "支出", "振替",
      "残高調整", "通貨変換前の金額", "集計の設定",
    ]
    csv_data.each do |data|
      number = data["No"].to_i
      shop = ""
      memo = ""
      category = "その他"
      details = "未分類"
      from = "PASMO"
      to = "-"
      payment = ""
      income = ""
      transfer = ""
      type = "payment"
      val = data["処理金額"]
      if val == "0" then
        next
      end
      date = DateTime.strptime(data["日付"], "%Y年%m月%d日")
      if data["詳細"].start_with?("入：") then
        # 電車
        category = "交通"
        details = "電車"
        converted_content = conv_content(data["詳細"])
        shop = converted_content[0]
        memo = converted_content[1]
        payment = val
      elsif data["処理"].include?("チャージ") then
        # チャージ
        category = ""
        details = ""
        from = "お財布"
        to = "PASMO"
        type = "transfer"
        transfer = val
      elsif buses.has_key?(data["詳細"]) then
        # バス
        category = "交通"
        details = "バス"
        shop = buses[data["詳細"]]
        payment = val
        STDOUT.puts "Bus: " + data.to_s
      else
        # 未分類
        payment = val
        STDERR.puts "Uncategorized: " + data.to_s
      end
      row = [
        date.strftime("%Y-%m-%d"), type,
        category, details,
        from, to,
        "", memo, shop,
        "", income, payment, transfer,
        "", "", "",
      ]
      if (number > last_no) then
        max_no = [max_no, number].max
        if (b_date.nil? or b_date > date) then
          b_date = date
        end
        if (e_date.nil? or e_date < date) then
          e_date = date
        end
        csv << row
      end
    end
  end
  if max_no > 0 then
    File.open("temp PASMO %s-%s L%d.csv" % [b_date.strftime("%Y%m%d"), e_date.strftime("%Y%m%d"), max_no], 'w') do |file|
      file.write(out_csv)
    end
  elsif
    STDERR.puts "There are no data"
  end
else
  STDERR.puts "Usage: convert.rb [<CSV filename>]"
end

