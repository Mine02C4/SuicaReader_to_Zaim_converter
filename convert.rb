require 'csv'

buses = {
  "京急バス" => "京浜急行バス",
  "伊豆箱根バス" => "伊豆箱根バス",
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
    /^PASMO [0-9]{8}-[0-9]{8}\.csv$/.match item
  }
  lastlog = pasmologs.sort {|a, b|
    regex = /PASMO [0-9]{8}-([0-9]{8})/
    regex.match(b).captures[0].to_i <=> regex.match(a).captures[0].to_i
  }[0]
  return CSV.read(lastlog, encoding: Encoding::SJIS).collect { |row|
    row[0].to_i
  }.sort {|a, b| b <=> a }.first
end

if ARGV.size == 1 then
  last_no = get_last_no
  csv_data = CSV.read(ARGV[0], encoding: "UTF-8", headers: true)
  b_date = nil
  e_date = nil
  out_csv = CSV.generate(encoding: Encoding::SJIS) do |csv|
    csv << [
      "No",
      "日付",
      "カテゴリ", "カテゴリ内訳",
      "メモ", "お店",
      "支払元", "入金先",
      "支出金額", "収入金額", "振替金額",
      "振替かどうか",
      "残高", "処理"
    ]
    csv_data.each do |data|
      shop = ""
      memo = ""
      category = "その他"
      details = "未分類"
      from = "PASMO"
      to = ""
      payment = ""
      income = ""
      transfer = ""
      type = ""
      val = data["処理金額"]
      if val == "0" then
        next
      end
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
        type = "振替"
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
        data["No"],
        data["日付"],
        category,
        details,
        memo, shop,
        from, to,
        payment, income, transfer,
        type,
        data["残高"], data["処理"]
      ]
      if (data["No"].to_i > last_no) then
        date = DateTime.strptime(data["日付"], "%Y年%m月%d日")
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
  File.open("temp PASMO %s-%s.csv" % [b_date.strftime("%Y%m%d"), e_date.strftime("%Y%m%d")], 'w') do |file|
    file.write(out_csv)
  end
else
  STDERR.puts "Usage: convert.rb [<CSV filename>]"
end

