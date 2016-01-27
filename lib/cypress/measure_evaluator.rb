# :nocov:
module Cypress
  class MeasureEvaluator
    def initialize(args = nil)
      @options = args ? args : {}
      @logger = Rails.logger
    end

    def evaluate_all_cat3(args = nil)
      opts = args ? @options.merge(args) : @options
      generate_tests(opts)

      wait_for_calculations

      upload_all_cat3s
    end

    def evaluate_all_cat1(args = nil)
      opts = args ? @options.merge(args) : @options
      generate_tests(opts)

      wait_for_calculations

      upload_all_cat1s
    end

    def cleanup(*)
      @logger.info 'Cleaning database...'
      Vendor.where(name: 'MeasureEvaluationVendor').destroy_all
      @logger.info 'done'
    end

    def generate_tests(args = nil)
      opts = args ? @options.merge(args) : @options

      @logger.info 'Generating Cat III tests...'
      tests = Measure.top_level.collect do |t|
        opts[:measure] = t
        generate_test(opts)
      end
      @logger.info 'done'
      tests
    end

    def generate_test(args = nil)
      opts = args ? @options.merge(args) : @options
      bundle_ver = opts[:version] ? opts[:version] : APP_CONFIG['default_bundle']
      bundle = Bundle.where(version: bundle_ver).first

      @logger.info "Generating test for #{opts[:measure].cms_id}"

      vendor = Vendor.find_or_create_by(name: 'MeasureEvaluationVendor')
      product = Product.find_or_create_by(name: 'MeasureEvaluationProduct', vendor_id: vendor.id, c1_test: true, c2_test: true, c3_test: true)

      MeasureTest.find_or_create_by(name: opts[:measure].name, bundle: bundle.id,
                                    product: product,
                                    measure_ids: [opts[:measure].hqmf_id],
                                    description: opts[:measure].description,
                                    cms_id: opts[:measure].cms_id)
    end

    # Waits until there are no tests with a state not equal to "ready"
    def wait_for_calculations
      @logger.info 'Waiting for calculations to finish...'
      product = Product.where(name: 'MeasureEvaluationProduct').first

      continuing = true
      while continuing
        sleep(2)
        continuing = ProductTest.where(state: 'pending', product: product).count > 0
      end
      @logger.info 'done'
    end

    def upload_all_cat3s
      upload_cat3s(Product.where(name: 'MeasureEvaluationProduct').first.product_tests)
    end

    def upload_cat3s(tests)
      tests.each do |t|
        @logger.info("Uploading cat3 for test #{t.id}")
        xml = generate_cat3(t.measure_ids, t)
        upload_cat3(t, xml)
      end
    end

    # Uploads a single Cat 3
    def upload_cat3(product_test, xml)
      # Generate a temporary file that acts just like a normal file, but is given a unique name in the './tmp' directory
      tmp = Tempfile.new(['qrda_upload', '.xml'], './tmp')
      tmp.write(xml)
      product_test.c2_task.execute(tmp)
    rescue StandardError => e
      @logger.error "Cat 3 test #{product_test.id} failed: #{e}"
    end

    def generate_cat3(measure_ids, test)
      zip = create_patient_zip(test.records)
      file = `bundle exec ruby ./script/cat_3_calculator.rb #{measure_opts_for(measure_ids)} --zipfile #{zip.path}`
      file
    end

    def upload_all_cat1s
      upload_cat1s(Product.where(name: 'MeasureEvaluationProduct').first.product_tests)
    end

    def upload_cat1s(tests)
      tests.each do |t|
        @logger.info("Uploading cat1 for test #{t.id}")
        upload_cat1(t)
      end
    end

    def upload_cat1(t)
      zip = create_patient_zip(t.c1_task.records)
      FileUtils.mv zip, "#{File.dirname(zip)}/#{File.basename(zip)}.zip"
      zip2 = File.new("#{File.dirname(zip)}/#{File.basename(zip)}.zip")
      t.c1_task.execute(zip2)
    rescue StandardError => e
      @logger.error "Cat 1 test #{t.id} failed: #{e}"
    end

    def measure_opts_for(measure_ids)
      '--measure ' + measure_ids.join(' --measure ')
    end

    def create_patient_zip(patients)
      Cypress::CreateDownloadZip.create_zip(patients, 'qrda')
    end
  end
end
