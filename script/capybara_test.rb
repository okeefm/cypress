#Run me by issuing the following command from the Cypress base dir, with the rails server
#and delayed worker running: 'bundle exec ruby script/capybara_test.rb'

ENV['HTTP_PROXY'] = ENV['http_proxy'] = nil
require 'cgi'
require 'timeout'
require 'capybara'
require 'capybara-webkit'
require 'capybara/poltergeist'
require 'pry'
require "show_me_the_cookies"

class CypressConnector
  include Capybara::DSL
  include ShowMeTheCookies
  attr_accessor :base, :test_links, :test_categories, :cleanup
  TEST_LINKS = "script/test_links.dat"

  def initialize(url, cleanup = nil)
    @cleanup = cleanup
    @base = url
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app,
        :timeout => 120)
    end
    Capybara.default_driver = :poltergeist
    restore_test_links
    # Capybara.default_driver = :selenium
  end

  #If we've already created a test, grab the links from the TEST_LINKS file,
  #So we don't have to recreate them
  def restore_test_links
    if File.size?(TEST_LINKS) && !@cleanup
      File.open(TEST_LINKS, "r") do |f|
        @test_links = Marshal.load(f)
      end
    else
      @test_links = Hash.new
    end
  end

  #dump the @test_links hash out to a file
  #So we can grab the state when we restart this task
  def dump_test_links
    File.open(TEST_LINKS, "w") do |f|
      Marshal.dump(@test_links, f)
    end
  end

  def visit_homepage
    visit @base
  end

  def sign_in
    visit_homepage

    #TODO: generate a user programmatically, and use that user here
    #For the time being, create a user and put its credentials here
    fill_in("user_email", with: "<user_email>")
    fill_in("user_password", with: "<password>")

    click_on('Login')
    visit_homepage
    #Has_link is a Capybara method that looks for a link with the specified text; 
    #if it exists and we're cleaning up, delete that test
    delete_vendor if has_link?("MeasureEvaluationVendor") && @cleanup

    if !has_link?("MeasureEvaluationVendor")
      create_vendor
      create_product
    end

    #Create cat3 tests if the number of tests is less than the total number of discrete cat3 tests,
    #If you make one for every EH/EP measure
    create_tests if num_tests < 94

    #Create cat1 tests if the number of tests is less than the total number of discrete cat1+cat3 tests,
    #if you make one each for every EH/EP measure
    create_cat1_tests if num_tests < 186

    execute_cat1_tests
  end

  def visit_product_page
    visit_homepage
    click_link("MeasureEvaluationVendor")
    click_link("MeasureEvaluationProduct")
  end

  def create_cat1_tests
    visit_product_page

    @test_links.each_value do |test|
      click_link test
      click_link "Generate"
    end
  end

  #Count all the test <span> objects on the MeasureEvaluationVendor page
  #(You can see these on the HTML page if you click the little arrow next to the product)
  def num_tests
    visit_homepage
    click_link("MeasureEvaluationVendor")
    find("td span.q").text.gsub(/\D/, "").to_i
  end

  def delete_vendor
    link = find_link("MeasureEvaluationVendor")
    vendor_id = link['href'].split("/").last
    delete_link = find(:xpath, "//a[@href='/vendors/#{vendor_id}'][@data-method='delete']")
    foo = ""
    begin
      #there is an alert that pops up on the page when you click any "delete" link
      #not sure why the accept_alert is commented out; it's been a while since I touched this
      # accept_alert do 
        delete_link.click
      # end
    rescue Exception => e
      # binding.pry
    ensure
      return
    end
  end

  def create_vendor
    click_link "Add EHR Vendor"
    fill_in("vendor_name", with: "MeasureEvaluationVendor")
    click_on "Create"
  end

  def create_product
    click_link "MeasureEvaluationVendor"
    click_link("Add Product", match: :first)

    fill_in("product_name", with: "MeasureEvaluationProduct")
    click_on "Create"
  end

  def create_tests
    click_link "MeasureEvaluationProduct"
    @test_categories = Hash.new
    i = 0
    test_hqmf, test_name = create_test("EP", i)
    while test_hqmf
      i += 1
      @test_links[test_hqmf] = test_name
      test_hqmf, test_name = create_test("EP", i)
    end

    dump_test_links
    @test_categories = Hash.new

    #The test measure picker loads the measures via AJAX (for some reason)
    #So we have to wait for these to load
    wait_for_ajax

    click_link "MeasureEvaluationProduct"

    i += 1
    test_hqmf, test_name = create_test("EH", i)
    while test_hqmf
      i += 1
      @test_links[test_hqmf] = test_name
      test_hqmf, test_name = create_test("EH", i)
    end
    dump_test_links
  end

  def create_test(test_type, i)
    click_link "Add Test", match: :first

    choose test_type

    fill_in "product_test_name", with: "MeasureEvaluationTest #{i}"
    click_on "Next"
    
    return pick_test_category, "MeasureEvaluationTest #{i}"
  end

  def pick_test_category
    begin
      wait_for_ajax
      all("input.measure_cb").each do |input|
        if !@test_links.include? input['id']
          id = input['id']
          check id
          click_on "Done"
          return id
        end
      end
      @test_categories["#{find('li.ui-state-active a')['id']}"] = "done"
      # binding.pry
      all("a.ui-tabs-anchor").each do |input|
        if !@test_categories.include?(input['id'])
          click_link input['id'] 
          return pick_test_category 
        end
      end
      return nil
    rescue Exception => e
      # binding.pry
    end
  end

  def wait_for_ajax
    Timeout.timeout(Capybara.default_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end

  def execute_cat1_tests
    visit_product_page
    @test_links.each_value do |test_name|
      click_link('a', :text => /#{test_name} -/i)
      zip = get_cat1_zip(page.current_url)
      binding.pry
    end
  end

  def get_cat1_zip(test_url)
    #TODO: <User_email> and <password> here also need to get replaced with the generated
    #username and password, once we generate one.
    `curl -X GET -u <user_email>:<password> #{test_url}/download.qrda`
    visit "#{test_url}/download.qrda"
  end

end

#Uncomment this line (and comment out the next line) to delete all the tests and start over
CypressConnector.new("http://localhost:3000", true).sign_in
CypressConnector.new("http://localhost:3000").sign_in
