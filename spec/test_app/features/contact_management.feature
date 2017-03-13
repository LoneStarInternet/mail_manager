Feature: Manage Contacts
  In order to value
  As a role
  I want feature

  Background:
    Given a contact named "Bob Dole" exists with email_address "bob@example.com"
    And I am logged in and authorized for everything

  Scenario: Search Contacts that exist
    When I go to the contacts page
    And I fill in "term" with "bob"
    And I press "Search"
    Then I should be on the contacts page
    And I should see "bob@example.com"
    
  Scenario: Search Contacts that don't exist
    When I go to the contacts page
    And I fill in "term" with "sam"
    And I press "Search"
    Then I should be on the contacts page
    And I should not see "bob@example.com"
  
  @javascript
  Scenario: Search for contacts by mailing list and status
   Given a contact named "Babs Dole" exists with email_address "babs@example.com"
     And a mailing list named "Peeps" exists
     And the contact named "Babs Dole" is subscribed to "Peeps"
    When I go to the contacts page
    Then I should see "bob@example.com"
     And I should see "babs@example.com"
    When I select "Peeps" from "Mailing List"
     And I select "Any" from "Status"
     And I press "Search"
    Then I should see "babs@example.com"
     And I should not see "bob@example.com"
    When I select "Pending" from "Status"
     And I press "Search"
    Then I should not see "babs@example.com"
     And I should not see "bob@example.com"

  Scenario: New contact
   Given a mailing list named "Peeps" exists
     And a mailing list named "Others" exists
    When I go to the new contact page
     And I fill in "First name" with "Bobo"
     And I fill in "Last name" with "Clown"
     And I fill in "Email address" with "bobo@example.com " 
     And I check "Peeps"
     And I press "Submit"
    Then contact "Bobo Clown" should exist with email_address "bobo@example.com"
     And contact "Bobo Clown" should be subscribed to "Peeps" with the "active" status

  Scenario: Soft Delete a contact
    When I go to the contacts page
     And I follow "Delete"
    Then I should be on the contacts page
     And the contact "Bob Dole" should be soft deleted
     And I should not see "Bob Dole"
    When I undelete contact "Bob Dole"
     And I go to the contacts page
    Then I should see "Bob Dole"
     

  Scenario: Edit contact
   Given a mailing list named "Peeps" exists
     And a mailing list named "Others" exists
    When I go to the contacts page
     And I follow "Edit"
     And I fill in "First name" with "Bobo"
     And I fill in "Last name" with "Clown"
     And I fill in "Email address" with " bobo@example.com" 
     And I check "Peeps"
     And I press "Submit"
    Then contact "Bobo Clown" should exist with email_address "bobo@example.com"
     And contact "Bobo Clown" should be subscribed to "Peeps" with the "active" status
    When I follow "Edit"
     And I check "Others"
     And I uncheck "Peeps"
     And I press "Submit"
    Then contact "Bobo Clown" should exist with email_address "bobo@example.com"
     And contact "Bobo Clown" should be subscribed to "Others" with the "active" status
     And contact "Bobo Clown" should be subscribed to "Peeps" with the "admin_unsubscribed" status
  
  Scenario: Many contacts existing will show pagination
   Given 50 contacts exist
    When I go to the contacts page
    Then I should see "Previous"
     And I should see "Next"
    When I follow "Next"

  # need to reincorproate double-opt-in subscribe
  @wip 
  Scenario: Subscribe to a list by email address(site form) with no redirect defined
   Given a mailing list named "Peeps" exists
    When I submit a static subscribe form for "Bobo Clown" with email address "bobo@example.com" and the mailing list named "Peeps"
    Then I should be on the mail manager thank you page
     And contact "Bobo Clown" should be subscribed to "Peeps" with the "pending" status 
