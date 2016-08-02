
require 'mechanize'
require 'dotenv'
Dotenv.load
def login(creds)
  agent = Mechanize.new

  # agent.set_handle_robots(false)
  puts "opening root #{creds[0]}"
  agent.get('https://28degrees-online.latitudefinancial.com.au/')
  puts "opening login"
  page = agent.get('https://28degrees-online.latitudefinancial.com.au/access/login')
  pp page

  if page.content.include? "Scheduled outage"
    puts 'scheduled outage'
    return nil
  end

  form = page.form
  form.USER = creds[0]
  form.PASSWORD = creds[1]
  response_page = agent.submit(form,form.buttons.first)
  # nAQ@#CV if text =~ /window.location = '\/access\/login'/iH1
  text = response_page.content
  # if text =~ /window.location = '\/access\/login'/i
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

def fetch_transactions agent

end

def write(transactions, file)

end

def export

  creds = [ENV["28DEGREES_USER"], ENV["28DEGREES_PW"]]
  agent = login creds
  if agent == nil
    return
  end
  agent = open_transactions_page agent
  if agent == nil
    return
  end

end

export