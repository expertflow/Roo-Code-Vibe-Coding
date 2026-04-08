# Bulk create Transaction from BankStatement
Status: Implementation Complete
The goal is to generate Transactions from BankStatement that are not yet linked to a Transaction.
The user clicks on a button (Directus Flow from the BankStatement collection). The program will then run through all BankStatement that are not yet linked to a Transaction and where a Correspondantbank is linked..
For each BankStatement:
If the Amount is positive, the OriginAccount is the BankStatement.Account and the DestinationAccount is the BankStatement.CorrespondantBank..
If the Amount is negative, the OriginAccount is the BankStatement.CorrespondantBank and the DestinationAccount is the BankStatement.Account.
Search for a Transactions that has +-5% the same absolute Amount as the BankStatement.Amound, whose date is +- 3 days,  whose OriginAccountand DestinationAccount are the same as determined above. 
If no such Transaction is found, create a new Transaction with the same Amount, Date, Project, Description as the BankStatement, and the OriginAccount and DestinationAccount as determined above, and Currency of the Account.Currency
Link the BankStatement to that existing or newly created Transaction and skip to the next BankStatement. 