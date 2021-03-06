include RecordsHelper
include ApplicationHelper

When(/^the user visits the records page$/) do
  visit '/records/'
  @bundle = Bundle.where(:records.exists => true).first
  @measure = @bundle.measures.where(hqmf_id: '8A4D92B2-3946-CDAE-0139-7944ACB700BD').first
end

Then(/^the user should see a list of patients$/) do
  page.assert_text 'All Patients'
  assert page.has_selector?('table tbody tr', count: @bundle.records.length), 'different count'
end

And(/^the user should see a way to filter patients$/) do
  page.assert_text 'Filter by Measure'
  options = ['All measures'] + @bundle.measures.map(&:display_name)
  assert page.has_select?('measure_id', options: options)
end

And(/^the user selects a measure from the dropdown$/) do
  page.select @measure.display_name, from: 'measure_id'
end

Then(/^the user should see results for that measure$/) do
  page.assert_text @measure.display_name + ' Patients'

  records = records_by_measure(@bundle.records, @measure)

  assert page.has_selector?('table tbody tr', count: records.length), 'different number'
  assert page.has_selector?('.result-marker'), 'no result marker'
end

When(/^the user visits a record$/) do
  @bundle = Bundle.where(:records.exists => true).first
  @record = @bundle.records.where(_id: '4efa05ada9ffcce9010000dc').first
  visit "/records/#{@record.id}"
end

Then(/^the user sees details$/) do
  page.assert_text "Patient Information for #{@record.first} #{@record.last}"
  page.assert_text display_time(@record.birthdate)
  page.assert_text full_gender_name(@record.gender)
  SECTIONS.each do |section|
    page.assert_text section.titleize

    next unless @record[section]
    @record[section].each do |data_criteria|
      page.assert_text data_criteria['description']
    end
  end

  result_value = @record.calculation_results.map(:value)
  @measures = @bundle.measures.where(:hqmf_id.in => result_value.map(&:measure_id)).where(:sub_id.in => result_value.map(&:sub_id))
  @measures.each do |m|
    page.assert_text m.display_name
  end
end
