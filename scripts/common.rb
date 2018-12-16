require 'selenium-webdriver'
require 'highline'
require 'csv'
require 'logger'

ROOT_DIR = File.expand_path '../..', __FILE__
TMP_DIR = File.expand_path 'tmp', ROOT_DIR
FileUtils.mkdir_p TMP_DIR

module ElementExtensions
  def set_text(text)
    clear
    send_keys(text)
  end
end


module ConnectYourCare
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

  URL = 'https://secure.connectyourcare.com/portal/CC'
  LOG = Logger.new File.open(File.join(TMP_DIR, 'logs.txt'), 'a') # create or append
  CLI = HighLine.new

  DRIVER = Selenium::WebDriver.for :chrome

  def set_cookies
    cookies = IO.foreach(File.join(TMP_DIR, 'cookies.txt')).map do |line|
      JSON.parse line
    end

    cookies.each do |cookie|
      DRIVER.manage.add_cookie(name: cookie['name'], value: cookie['value'])
    end
  end

  def login_to_hsa
    username = CLI.ask('Enter username: ') { |q| q.default = 'caylan' }
    password = CLI.ask('Enter password: ') { |q| q.echo = false }

    # Set cookies and refresh
    DRIVER.navigate.to URL
    set_cookies
    DRIVER.navigate.refresh

    # Login
    DRIVER.find_element(id: 'usernameId').set_text(username)
    DRIVER.find_element(id: 'password').set_text(password)
    DRIVER.find_element(id: 'submit').click
  end
end

class ::Selenium::WebDriver::Element
  prepend ElementExtensions
end
