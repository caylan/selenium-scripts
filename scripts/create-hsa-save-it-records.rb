require 'selenium-webdriver'
require 'highline'
require 'csv'
require 'logger'

require_relative 'common'

include ConnectYourCare

login_to_hsa

claims_location = CLI.ask('Enter location of claims file: ') { |q| q.default = File.join(TMP_DIR, 'claims.csv') }
claims = Claims.new(claims_location).claims

# Create new HSA Save-It records
claims.each do |claim|
  DRIVER.navigate.to 'https://secure.connectyourcare.com/portal/CC/cdhportal/cdhclaims/saveforlater'

  # Set date
  DRIVER.find_element(id: 'dateOfService').set_text(claim['date'])
  DRIVER.find_element(xpath: '//*[@id="claimTemplate"]/div[4]/input[2]').click

  # Set details
  DRIVER.find_element(id: 'claim_claimAmount').set_text(claim['amount'])

  type = Selenium::WebDriver::Support::Select.new(DRIVER.find_element(id: 'claim_serviceType'))
  type.select_by(:text, claim['type']) # e.g. 'Prescription Drugs'

  DRIVER.find_element(id: 'claim_vendor').set_text(claim['vendor']) # e.g. 'Bartell Drugs'
  DRIVER.find_element(id: 'claim_description').set_text(claim['description'])

  DRIVER.find_element(name: '_eventId_next').click

  # Confirm details
  unless CLI.agree('Continue? (y/n)', character = true)
    DRIVER.quit
    exit
  end

  DRIVER.find_element(name: '_eventId_next').click

  # Don't upload documentation/receipts
  DRIVER.find_elements(name: 'docs').find { |el| el.property('value') == 'noThanks' }.click
  DRIVER.find_element(id: 'reviewAccept').click

  # Submit the claim
  DRIVER.find_element(name: '_eventId_next').click

  LOG.info("Created the claim #{claim}")
end

DRIVER.quit
