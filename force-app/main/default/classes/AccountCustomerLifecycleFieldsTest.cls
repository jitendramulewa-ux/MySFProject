@isTest
private class AccountCustomerLifecycleFieldsTest {
    @isTest
    static void verifiesCustomerTierAndRenewalDate() {
        Schema.DescribeFieldResult tierDescribe = Account.Customer_Tier__c.getDescribe();
        System.assertEquals(Schema.DisplayType.PICKLIST, tierDescribe.getType());

        Set<String> actualTierValues = new Set<String>();
        for (Schema.PicklistEntry entry : tierDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                actualTierValues.add(entry.getValue());
            }
        }
        System.assertEquals(
            new Set<String>{ 'Gold', 'Silver', 'Bronze' },
            actualTierValues
        );

        Schema.DescribeFieldResult renewalDescribe = Account.Renewal_Date__c.getDescribe();
        System.assertEquals(Schema.DisplayType.DATE, renewalDescribe.getType());

        Account testAccount = new Account(
            Name = 'KAN-16 Account',
            Customer_Tier__c = 'Gold',
            Renewal_Date__c = Date.newInstance(2027, 1, 15)
        );
        insert testAccount;

        testAccount = [
            SELECT Customer_Tier__c, Renewal_Date__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('Gold', testAccount.Customer_Tier__c);
        System.assertEquals(Date.newInstance(2027, 1, 15), testAccount.Renewal_Date__c);

        testAccount.Customer_Tier__c = 'Silver';
        testAccount.Renewal_Date__c = Date.newInstance(2027, 6, 30);
        update testAccount;

        testAccount = [
            SELECT Customer_Tier__c, Renewal_Date__c
            FROM Account
            WHERE Id = :testAccount.Id
        ];
        System.assertEquals('Silver', testAccount.Customer_Tier__c);
        System.assertEquals(Date.newInstance(2027, 6, 30), testAccount.Renewal_Date__c);

        Account invalidTierAccount = new Account(Name = 'KAN-16 Invalid Tier');
        invalidTierAccount.put('Customer_Tier__c', 'Platinum');
        Database.SaveResult invalidResult = Database.insert(invalidTierAccount, false);
        System.assertEquals(false, invalidResult.isSuccess());
        System.assertEquals(
            StatusCode.INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST,
            invalidResult.getErrors()[0].getStatusCode()
        );
    }
}
