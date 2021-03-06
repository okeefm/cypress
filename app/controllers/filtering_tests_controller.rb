class FilteringTestsController < ProductTestsController
  before_action :set_product

  def new
    @filtering_test = @product.product_tests.build({}, FilteringTest)
  end

  def create
    @filtering_test = @product.product_tests.build(params[:product_tests], FilteringTest)

    @filtering_test.name = "C4 #{@product.name}"
    measure = Measure.top_level.first
    # TODO: This shouldn't default to first measures, measures need to be stored on the product
    @filtering_test.measure_ids = [measure.id]
    @filtering_test.bundle_id = measure.bundle_id
    @filtering_test.save!
    redirect_to vendor_product_filtering_tests_path(@product.vendor, @product)
  end

  def index
    @tests = @product.product_tests
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end
end
