require 'selenium-webdriver'
require 'highline'
require 'csv'
require 'logger'

require_relative 'common'

# Claims file helper.
#
# Expects a CSV in the following format:
#   Date,Amount,Type,Vendor,Description
#
# Example:
#   01/16/2017,$9.96,Prescription Drugs,Bartell Drugs,Allergy Medicine 200mg
class Claims
  attr_reader :claims

  def initialize(location)
    @location = location
    @claims = []

    keys = %w[date amount type vendor description]
    if File.exist? @location
      @claims = CSV.read(@location).map { |claim| Hash[ keys.zip(claim) ] }
    end
  end
end

log_file = File.open(File.join(TMP_DIR, 'logs.txt'), 'a') # create or append
logger = Logger.new log_file

cookies = IO.foreach(File.join(TMP_DIR, 'cookies.txt')).map do |line|
  JSON.parse line
end

cli = HighLine.new

username = cli.ask('Enter username: ') { |q| q.default = 'caylan' }
password = cli.ask('Enter password: ') { |q| q.echo = false }
claims_location = cli.ask('Enter location of claims file: ') { |q| q.default = File.join(TMP_DIR, 'claims.csv') }

claims = Claims.new(claims_location).claims

driver = Selenium::WebDriver.for :chrome
wait = Selenium::WebDriver::Wait.new(timeout: 120) # seconds

# Set cookies and refresh
driver.navigate.to 'https://secure.connectyourcare.com/portal/CC'
cookies.each do |cookie|
  driver.manage.add_cookie(name: cookie['name'], value: cookie['value'])
end
driver.navigate.refresh

# Login
driver.find_element(id: 'usernameId').set_text(username)
driver.find_element(id: 'password').set_text(password)
driver.find_element(id: 'submit').click

# Create new HSA Save-It records
claims.each do |claim|
  driver.navigate.to 'https://secure.connectyourcare.com/portal/CC/cdhportal/cdhclaims/saveforlater'

  # Set date
  driver.find_element(id: 'dateOfService').set_text(claim['date'])
  driver.find_element(xpath: '//*[@id="claimTemplate"]/div[4]/input[2]').click

  # Set details
  driver.find_element(id: 'claim_claimAmount').set_text(claim['amount'])

  type = Selenium::WebDriver::Support::Select.new(driver.find_element(id: 'claim_serviceType'))
  type.select_by(:text, claim['type']) # e.g. 'Prescription Drugs'

  driver.find_element(id: 'claim_vendor').set_text(claim['vendor']) # e.g. 'Bartell Drugs'
  driver.find_element(id: 'claim_description').set_text(claim['description'])

  driver.find_element(name: '_eventId_next').click

  # Confirm details
  unless cli.agree('Continue? (y/n)', character = true)
    driver.quit
    exit
  end

  driver.find_element(name: '_eventId_next').click

  # Don't upload documentation/receipts
  driver.find_elements(name: 'docs').find { |el| el.property('value') == 'noThanks' }.click
  driver.find_element(id: 'reviewAccept').click

  # Submit the claim
  driver.find_element(name: '_eventId_next').click

  logger.info("Created the claim #{claim}")
end

driver.quit
