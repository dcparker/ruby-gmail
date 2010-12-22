require 'test_helper'

class GmailTest < Test::Unit::TestCase
  def test_initialize
    imap = mock('imap')
    Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(imap)
    gmail = Gmail.new('test', 'password')
  end
  
  def test_imap_does_login
    setup_mocks()

    @imap.expects(:login).with('test@gmail.com', 'password').returns(@ok_res)
    @gmail.imap
  end

  def test_imap_does_login_only_once
    setup_mocks()

    @imap.expects(:login).with('test@gmail.com', 'password').returns(@ok_res)
    @gmail.imap
    @gmail.imap
    @gmail.imap
  end

  def test_imap_does_login_without_appending_gmail_domain
    setup_mocks()

    @imap.expects(:login).with('test@gmail.com', 'password').returns(@ok_res)

    @gmail.imap
  end
  
  def test_imap_logs_out
    setup_mocks()

    @imap.expects(:login).with('test@gmail.com', 'password').returns(@ok_res)

    @gmail.imap
    @imap.expects(:logout).returns(@ok_res)
    @gmail.logout
  end

  def test_imap_logout_does_nothing_if_not_logged_in
    setup_mocks(:at_exit => false)

    @imap.expects(:logout).never
    @gmail.logout
  end
  
  def test_imap_calls_create_label 
     setup_mocks :login => true

    @imap.expects(:create).with('foo')
    @gmail.create_label('foo')
  end

  def test_imap_find_inbox
	  setup_mocks :login => true
      add_xlist_mocks

	  inbox = @gmail.inbox
	  assert_equal 'Inbox', inbox.name
  end

  def test_find_label
	  setup_mocks :login=>true
	  add_xlist_mocks

	  sent_box = @gmail.label_of_type :Sent

	  assert_equal '[Google Mail]/Sent Mail', sent_box
  end

  def test_labels
	  setup_mocks(:login => true)
	  add_list_mocks

	  assert_equal ['Inbox', '[Google Mail]/Sent Mail'], @gmail.labels
  end

  def test_normal_labels
	  setup_mocks(:login => true)
	  add_xlist_mocks

     assert_equal ['Personal'], @gmail.normal_labels
  end

  def test_search
	  setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :mailbox => '[Google Mail]/Sent Mail'

	  result = @gmail.sent.emails(:after => Date.today)

	  assert result.empty?
  end

  def test_search_and_fetch
      setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :uids => [1,2,3],
		  :fetch => true,
		  :results => [ email_mock(1), email_mock(2), email_mock(3) ]

	  result = @gmail.inbox.emails(:after => Date.today, :fetch => true)

	  assert_instance_of Gmail::MessageList, result
	  assert_equal 3, result.size
  end
  
  def test_search_and_fetch_with_filter
      setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :uids => [1,2,3],
		  :fetch => true,
		  :results => [ email_mock(1), email_mock(2), email_mock(3) ]

	  result = @gmail.inbox.emails(:after => Date.today, :fetch => true)

	  add_search_mocks :search => [ 'OR', 'OR', 'HEADER', 'Message-ID', '<test-uid-1@gmail.com>', 'HEADER', 
		  'Message-ID', '<test-uid-2@gmail.com>', 'HEADER', 'Message-ID', '<test-uid-3@gmail.com>' ],
		  :uids => [2, 3],
		  :mailbox => '[Google Mail]/Sent Mail',
		  :results => [ email_mock(2, false), email_mock(3, false) ]

      result = result.with_label('[Google Mail]/Sent Mail')

	  assert_instance_of Gmail::MessageList, result
	  assert_equal 2, result.size
  end

    
  def test_search_with_fetch_and_check_subject
      setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :uids => [1],
		  :fetch => true,
		  :results => [ email_mock(1) ]

	  result = @gmail.inbox.emails(:after => Date.today, :fetch => true)

	  assert_instance_of Gmail::MessageList, result
	  assert_equal 1, result.size

	  assert_equal "Subject 1", result.list[0].subject
  end
  
  def test_search_and_then_fetch_rfc822
      setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :uids => [1],
		  :fetch => false,
		  :results => [ email_mock(1) ]

	  result = @gmail.inbox.emails(:after => Date.today, :fetch => false)

	  assert_instance_of Gmail::MessageList, result
	  assert_equal 1, result.size

	  response = mock("response-#{1}")
	  response.stubs(:attr).returns('RFC822'=>body_for_uid(1))
	  @imap.expects(:uid_fetch).with(1, 'RFC822').returns([response])

	  assert_equal "header-#{1}", result.list[0].header['X-Extra-Header'].value
  end

  def test_search_and_then_fetch_rfc822_doesnt_fetch_if_filter_result_is_empty
      setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :uids => [1, 2, 3, 4],
		  :fetch => true,
		  :results => [ email_mock(1), email_mock(2), email_mock(3), email_mock(4)]

	  result = @gmail.inbox.emails(:after => Date.today, :fetch => true)

	  add_search_mocks :search => [ 'OR', 'OR', 'OR', 'HEADER', 'Message-ID', '<test-uid-1@gmail.com>', 'HEADER',
		  'Message-ID', '<test-uid-2@gmail.com>', 'HEADER', 'Message-ID', '<test-uid-3@gmail.com>',
	     'HEADER', 'Message-ID', '<test-uid-4@gmail.com>' ],
		  :uids => [],
		  :mailbox => '[Google Mail]/Sent Mail',
		  :results => [ ],
		  :assert_never_fetches => true

      result = result.with_label('[Google Mail]/Sent Mail')

	  assert_instance_of Gmail::MessageList, result
	  assert_equal 0, result.size
  end

  def test_empty_search_doesnt_search_on_filter
	  setup_mocks :login => true
	  add_xlist_mocks
	  add_search_mocks :uids => []

	  result = @gmail.inbox.emails(:after => Date.today)

	  result = result.with_label('[Google Mail]/Sent Mail')

	  assert_instance_of Gmail::MessageList, result
	  assert_equal 0, result.size
  end

  def test_auto_segment
	  count = 0

	  result = Gmail.auto_segment((0..99).to_a, 5) do |list|
		  count += 1
		  list.map { |i| i * 2 }
	  end

	  assert_equal 20, count
	  assert_equal (0..99).map{|i|i*2}, result
  end
  
  private
  def body_for_uid(uid)
	  str = <<-EOB
From: sender-#{uid}@gmail.com
Message-Id: <test-uid-#{uid}@gmail.com>
To: recipient-#{uid}@gmail.com
Subject: Subject #{uid}
Content-Type: text/plain; charset=UTF-8
X-Extra-Header: header-#{uid}

Message Body #{uid}
EOB
  end

  def email_mock(uid, add_body = true)
	  envelope = mock("envelope-#{uid}")
	  envelope.stubs(:message_id).returns("<test-uid-#{uid}@gmail.com>")
	  envelope.stubs(:subject).returns("Subject #{uid}")
      envelope.stubs(:to).returns("recipient-#{uid}@gmail.com")
	  envelope.stubs(:from).returns("sender-#{uid}@gmail.com")

	  body = body_for_uid(uid)
	  obj = mock("fetch-response-#{uid}")
	  attr = {'ENVELOPE' => envelope,  'UID' => uid}
	  attr['RFC822'] = body if add_body
	  obj.stubs(:attr).returns(attr)
	  obj
  end

  def add_search_mocks(options={})
	  options[:search] ||= ['ALL', 'SINCE', Time.now.to_imap_date]
	  options[:uids] ||= []
	  options[:results] ||= options[:uids].map { |uid| email_mock(uid) }
	  options[:mailbox] ||= 'Inbox'

	  @imap.expects(:select).with(options[:mailbox])

	  uid_list = []
	  @imap.expects(:uid_search).
		  with(options[:search]).
		  returns(options[:uids])

	  if options[:uids].empty?
		 if options[:assert_never_fetches]
           @imap.expects(:uid_fetch).never
		 end
	  else
         @imap.expects(:uid_fetch).
			  with(options[:uids], (options[:fetch] ? ['ENVELOPE', 'RFC822'] : ['ENVELOPE'])).
			  returns(options[:results])
	  end
  end

  def mail_mock(name, *flags)
      resp = mock(name)
	  resp.stubs(:attr).returns(flags)
	  resp.stubs(:name).returns(name)
      resp
  end

  def add_list_mocks
	  list = []

	  list << mail_mock('Inbox', :Hasnochildren)
	  list << mail_mock('[Google Mail]', :Haschildren, :Noselect)
	  list << mail_mock('[Google Mail]/Sent Mail', :Hasnochildren)
	  
	  @imap.expects(:list).with('', '*').returns(list)
  end


  def add_xlist_mocks
	  xlist = []

	  xlist << mail_mock('Inbox', :Hasnochildren, :Inbox)
	  xlist << mail_mock('Personal', :Hasnochildren)
	  xlist << mail_mock('[Google Mail]', :Haschildren, :Noselect)
	  xlist << mail_mock('[Google Mail]/Sent Mail', :Hasnochildren, :Sent)

	  @imap.expects(:xlist).with('', '*').returns(xlist)
  end

  def setup_mocks(options = {})
    options = {:at_exit => true}.merge(options)
    @imap = mock('imap')
	@ok_res = mock('res')
	@ok_res.stubs(:name).returns('OK')
    Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(@imap)
    @gmail = Gmail.new('test@gmail.com', 'password')

    @imap.expects(:login).with('test@gmail.com', 'password').returns(@ok_res) if options[:login]
    
    # need this for the at_exit block that auto-exits after this test method completes
    @imap.expects(:logout).at_least(0).returns(@ok_res) if options[:at_exit]
  end
end
