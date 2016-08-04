
require 'mechanize'
require 'dotenv'
require 'csv'

Dotenv.load
def login(creds)
  agent = Mechanize.new

  # agent.set_handle_robots(false)
  puts "opening root"
  agent.get('https://28degrees-online.latitudefinancial.com.au/')
  puts "opening login"
  page = agent.get('https://28degrees-online.latitudefinancial.com.au/access/login')
  pp page

  if page.content.include? "Scheduled outage"
    puts 'scheduled outage'
    return nil
  end

  puts "Logging in as #{creds[0]}"
  form = page.form
  form.USER = creds[0]
  form.PASSWORD = creds[1]
  response_page = agent.submit(form,form.buttons.first)
  text = response_page.content
  if text.downcase.include? "window.location = '/access/login';"
    puts 'login failed?'
    nil
  else
    puts 'login success'
    return agent
  end
end

def open_transactions_page agent
  text = agent.page.content

  if agent.page.links.count == 0
    puts('Unable to locate link to main page')
    return nil
  end

  agent.page.links.first.click

  # untested
  if text.include? "please provide the answer to your secret question"
    puts('28degrees site requires you to validate this computer first.')
    puts('Please log into the website from your browser on this computer and answer verification question when prompted.')
    return nil
  end

  # untested
  if text.include? 'Have you received your new card?'
    cancelButtons = agent.at('input[name="cancelButton"]')
    if cancelButtons.count == 0
      puts('No cancel button found on "New card required" page')
      return nil
    end

    cancelLink = cancelButtons.first.parent.search('a')
    if cancelLink == nil
      puts('No cancel link found.')
      return nil
    end

    # Cancel new card number submission
    agent.open('https://28degrees-online.latitudefinancial.com.au' + cancelLink.href)
    agent.open('https://28degrees-online.latitudefinancial.com.au/wps/myportal/ge28degrees/public/account/transactions/')
  end

  puts "on transaction page"
  agent
end

class Transaction
  attr_accessor :date, :memo, :amount_cents

  def date=(date)
    @date = DateTime.parse(date)
  end
  def amount_str=(amount_str)
    @amount_cents = (amount_str.gsub(/[^\d\.-]/, '').to_f * 100).to_i
  end

  def memo=(memo)
    @memo = memo.gsub(/\s+/, ' ')
  end

  def to_csv
    [@date.strftime("%F"), @amount_cents, @memo]
  end
end

def fetch_transactions page
  trans = []

  page.css('div[name="transactionsHistory"]').css('tr[name="DataContainer"]').map do |row|
    t = Transaction.new
    t.date = row.css('div[name="Transaction_TransactionDate"]').text
    t.memo = row.css('div[name="Transaction_TransactionDescription"]').text
    t.amount_str = row.css('div[name="Transaction_Amount"]').text

    trans.push t
  end

  trans
end

def write(transactions, file)
  raise "Unsupported extension: #{File.extname(file)}" if File.extname(file).downcase != '.csv'

  dir = File.dirname(file)
  puts "Creating #{dir} if necessary"
  Dir.mkdir(dir) unless File.exists?(dir)

  puts "Writing #{transactions.length} transactions"

  # IO.write(file, transactions.map(&:to_csv).join)
  rows = transactions.inject(['date','amount_cents','memo']) do |acc,el|
    acc.push el.to_csv
  end
  CSV.open(file, 'w') do |csv_object|
    csv_object << ['date','amount_cents','memo']
    transactions.each do |transaction|
      csv_object << transaction.to_csv
    end
  end
end

#Read transactions from file
def read(file)
  return [] unless File.exists? file

  transactions = []
  CSV.foreach(file, headers:true) do |row|
    t = Transaction.new
    t.date = row['date']
    t.amount_cents = row['amount_cents']
    t.memo = row['memo']
    transactions.push t
  end
  transactions
end

def export
  file = File.expand_path(ENV['TRANSACTIONS_DIR'] + '/28degrees.csv')

  prev_trans = read file

  creds = [ENV["28DEGREES_USER"], ENV["28DEGREES_PW"]]
  agent = login creds
  if agent == nil
    return
  end
  agent = open_transactions_page agent
  if agent == nil
    return
  end
  trans = []

  # next_button =
  trans += (fetch_transactions agent.page)

  puts "Fetched #{trans.length} transactions:"
  pp trans


  merged_trans = prev_trans | trans
  write merged_trans, file

  puts File.open(file, "rb").read
end

export