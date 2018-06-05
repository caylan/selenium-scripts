require 'selenium-webdriver'
require 'highline'
require 'yaml'

require_relative 'common'

# Helper to answer security questions.
# Stores answers in a local file after the first time.
class Answers
  def initialize(cli, location)
    @cli = cli
    @location = location
    @answers = {}

    if File.exist? @location
      @answers = YAML.load_file @location
    end
  end

  def answer(question)
    answer = @answers[question]
    if answer.nil?
      answer = @cli.ask(question)
      @answers[question] = answer
      File.write(@location, @answers.to_yaml)
    end
    answer
  end
end

cli = HighLine.new
answers = Answers.new(cli, '.answers.yml')

username = cli.ask('Enter username: ') { |q| q.default = 'caylan' }
password = cli.ask('Enter password: ') { |q| q.echo = false }

driver = Selenium::WebDriver.for :chrome
wait = Selenium::WebDriver::Wait.new(timeout: 120) # seconds

# Login
driver.navigate.to 'https://secure.connectyourcare.com/portal/CC'
driver.find_element(id: 'usernameId').set_text(username)
driver.find_element(id: 'submit').click
driver.find_element(id: 'password').set_text(password)
driver.find_element(id: 'submit').click

# Go to investments page
investment_url = 'https://secure.connectyourcare.com/portal/CC/cdhportal/cdhaccount/hsabinvestments'
driver.navigate.to investment_url

# Answer security question, save new answers to file
question = driver.find_element(id: 'ChallengeQuestionLabel').text

driver.find_element(id: 'AnswerText').set_text answers.answer(question)
driver.find_element(id: 'BtnContinue').click

# Go to transfer page
driver.navigate.to 'https://secure.hsabank.com/ibanking3/Transfers_Payments/create_transfer.aspx'

# Select accounts
source = Selenium::WebDriver::Support::Select.new(driver.find_element(id: 'ddlFundAccount'))
source.options.each_with_index do |option, idx|
  if option.text =~ /HSABank/
    source.select_by(:index, idx)
  end
end

dest = Selenium::WebDriver::Support::Select.new(driver.find_element(id: 'ddlDestAccount'))
dest.options.each_with_index do |option, idx|
  if option.text =~ /Ameritrade/
    dest.select_by(:index, idx)
  end
end

# Grab available balance
amount = /\$\d+\.\d+/.match(driver.find_element(id: 'lblFundBalance').text).to_s
driver.find_element(id: 'txtAmount').set_text amount
driver.find_element(id: 'btnSubmit').click

# Confirm final amount
puts driver.find_element(id: 'tblConfirmation').text
if cli.agree('Is this OK?')
  driver.find_element(id: 'btnSubmit').click
else
  cli.say("I'll wait.")
  wait.until { false }
end

driver.quit
