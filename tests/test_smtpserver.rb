require_relative 'em_test_helper'
require 'net/smtp'

class TestSmtpServer < Test::Unit::TestCase

  # Don't test on port 25. It requires superuser and there's probably
  # a mail server already running there anyway.
  Localhost = "127.0.0.1"
  Localport = 25001

  # This class is an example of what you need to write in order
  # to implement a mail server. You override the methods you are
  # interested in. Some, but not all, of these are illustrated here.
  #
  class Mailserver < EM::Protocols::SmtpServer

    attr_reader :my_msg_body, :my_sender, :my_recipients, :messages_count

    def initialize *args
      super
    end

    def receive_sender sender
      @my_sender = sender
      #p sender
      true
    end

    def receive_recipient rcpt
      @my_recipients ||= []
      @my_recipients << rcpt
      true
    end

    def receive_data_chunk c
      @my_msg_body = c.last
    end

    def receive_message
      @messages_count ||= 0
      @messages_count += 1
      true
    end

    def connection_ended
      EM.stop
    end
  end

  def run_server
    c = nil
    EM.run {
      EM.start_server( Localhost, Localport, Mailserver ) {|conn| c = conn}
      EM::Timer.new(2) {EM.stop} # prevent hanging the test suite in case of error
      yield if block_given?
    }
    c
  end

  def test_mail
    c = run_server do
      EM::Protocols::SmtpClient.send :host=>Localhost,
        :port=>Localport,
        :domain=>"bogus",
        :from=>"me@example.com",
        :to=>"you@example.com",
        :header=> {"Subject"=>"Email subject line", "Reply-to"=>"me@example.com"},
        :body=>"Not much of interest here."
    end
    assert_equal( "Not much of interest here.", c.my_msg_body )
    assert_equal( "<me@example.com>", c.my_sender )
    assert_equal( ["<you@example.com>"], c.my_recipients )
  end



  def test_multiple_messages_per_connection
    c = run_server do
      Thread.new do
        Net::SMTP.start( Localhost, Localport, Localhost ) do |smtp|
          2.times do
            smtp.send_message  "This is a test e-mail message.", 'me@fromdomain.com', 'test@todomain.com'
          end
        end
      end
    end

    assert_equal( 2, c.messages_count )
  end
end
