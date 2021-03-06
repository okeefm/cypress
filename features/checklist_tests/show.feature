Feature: C1 Visual Checklist Test

Background:
  Given the user is signed in
  And the user has created a vendor with a product selecting C1 testing and 5 measures
  And the user views that product

Scenario: Successful Revisit Checklist Test
  When the user generates a checklist test
  And the user views that product
  And the user views the manual entry tab
  Then the user should see a button to revisit the checklist test
  Then the page should be accessible according to: section508
  Then the page should be accessible according to: wcag2aa

Scenario: Successful Delete Checklist Test
  When the user generates a checklist test
  And the user views that checklist test
  And the user deletes the checklist test
  Then the user should be able to generate another checklist test
  Then the page should be accessible according to: section508
  Then the page should be accessible according to: wcag2aa
