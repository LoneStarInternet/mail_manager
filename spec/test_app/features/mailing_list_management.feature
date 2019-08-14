Feature: Mailing List Management
	In order have mailing lists
	As a valid user
	I want to create, modify and destroy mailing lists

  Background:
   Given I am logged in and authorized for everything

  Scenario: Create a Mailing List
   When I go to the mailing lists page
    And I follow "New Mailing List"
    And I fill in "Name" with "Bobo's Mailing List"
    And I fill in "Description" with "Bobo's mailing list is Awesome!"
    And I press "Submit"
   Then I should see "Mailing List was successfully created"
    And a mailing list named "Bobo's Mailing List" should exist
    
  Scenario: Edit a Mailing List
   Given a mailing list named "Funk" exists
    When I go to the mailing lists page
     And I follow "Edit"
     And I fill in "Name" with "Junk"
     And I press "Submit"
   Then I should see "Mailing List was successfully updated"
    And a mailing list named "Junk" should exist

  Scenario: Mailing Lists can be destroyed
   Given a mailing list named "Funk" exists
    When I go to the mailing lists page
     And I follow "Delete"
    Then I should see "Mailinglist successfully deleted."
     And I should not see "Funk"
  
  Scenario: Mailing lists paginate
   Given 50 mailing lists exist
    When I go to the mailing lists page
    Then I should see "Previous"
     And I should see "Next"
    When I follow "Next"
