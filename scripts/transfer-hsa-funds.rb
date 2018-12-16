require 'selenium-webdriver'
require 'highline'
require 'yaml'

require_relative 'common'

include ConnectYourCare

login_to_hsa

# Go to investments page
investment_url = 'https://secure.connectyourcare.com/portal/CC/cdhportal/cdhaccount/hsabinvestments'
DRIVER.navigate.to investment_url

# Go to transfer page
DRIVER.navigate.to 'https://secure.hsabank.com/ibanking3/Transfers_Payments/create_transfer.aspx'

# Select accounts
source = Selenium::WebDriver::Support::Select.new(DRIVER.find_element(id: 'ddlFundAccount'))
source.options.each_with_index do |option, idx|
  if option.text =~ /HSABank/
    source.select_by(:index, idx)
  end
end

dest = Selenium::WebDriver::Support::Select.new(DRIVER.find_element(id: 'ddlDestAccount'))
dest.options.each_with_index do |option, idx|
  if option.text =~ /Ameritrade/
    dest.select_by(:index, idx)
  end
end

# Grab available balance
amount = /\$\d+\.\d+/.match(DRIVER.find_element(id: 'lblFundBalance').text).to_s
DRIVER.find_element(id: 'txtAmount').set_text amount
DRIVER.find_element(id: 'btnSubmit').click

# Confirm final amount
puts DRIVER.find_element(id: 'tblConfirmation').text
if CLI.agree('Is this OK? (y/n)', character = true)
  DRIVER.find_element(id: 'btnSubmit').click
else
  CLI.say("I'll wait.")
  wait.until { false }
end

DRIVER.quit
