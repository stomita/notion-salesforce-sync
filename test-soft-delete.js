const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  
  // Navigate to scratch org
  await page.goto('https://power-fun-271-dev-ed.scratch.my.salesforce.com/secur/frontdoor.jsp?sid=00DHy000000eJvt!AR8AQLnii70N.RZ7JEp4oSAbgjnrr5heU4vf.EguBKIO2VJabkSTQEZ5qKwa5JKZNE67nXbcdRUmViQbusbH.kN7t7cEv69c', { waitUntil: 'domcontentloaded' });
  
  // Wait for the app to fully load
  await page.waitForTimeout(5000);
  
  // Navigate directly to Notion Sync Admin tab
  await page.goto('https://power-fun-271-dev-ed.scratch.my.salesforce.com/lightning/n/Notion_Sync_Admin', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);
  
  // Wait for the component to load
  await page.waitForSelector('c-notion-sync-summary', { timeout: 10000 });
  
  // Count initial configurations
  const initialRows = await page.$$('tbody tr');
  console.log(`Initial configuration count: ${initialRows.length}`);
  
  // Get the names of all configurations
  const configNames = [];
  for (const row of initialRows) {
    const nameText = await row.$eval('td:first-child', el => el.textContent);
    configNames.push(nameText.trim());
  }
  console.log('Configurations:', configNames);
  
  // Find and click delete button for Test_Parent_Object__c
  const deleteButtons = await page.$$('button:has-text("Delete")');
  
  if (deleteButtons.length > 0) {
    // Find the row with Test_Parent_Object__c and click its delete button
    const rows = await page.$$('tbody tr');
    for (let i = 0; i < rows.length; i++) {
      const rowText = await rows[i].textContent();
      if (rowText.includes('Test_Parent_Object__c')) {
        const rowDeleteButton = await rows[i].$('button:has-text("Delete")');
        if (rowDeleteButton) {
          await rowDeleteButton.click();
          console.log('Clicked delete for Test_Parent_Object__c');
          break;
        }
      }
    }
    
    // Wait for confirmation modal
    await page.waitForSelector('text=Delete Configuration', { timeout: 5000 });
    console.log('Delete confirmation modal appeared');
    
    // Confirm delete
    await page.click('button.slds-button_destructive:has-text("Delete")');
    console.log('Confirmed delete operation');
    
    // Wait for toast notification
    await page.waitForTimeout(2000);
    
    console.log('\nWaiting 20 seconds for metadata deployment to complete...');
    await page.waitForTimeout(20000);
    
    // Manually refresh the page
    console.log('Refreshing the page...');
    await page.reload();
    await page.waitForTimeout(3000);
    
    // Wait for the component to load again
    await page.waitForSelector('c-notion-sync-summary', { timeout: 10000 });
    
    // Count final configurations
    const finalRows = await page.$$('tbody tr');
    console.log(`\nFinal configuration count: ${finalRows.length}`);
    
    // Get the names of remaining configurations
    const finalConfigNames = [];
    for (const row of finalRows) {
      const nameText = await row.$eval('td:first-child', el => el.textContent);
      finalConfigNames.push(nameText.trim());
    }
    console.log('Remaining configurations:', finalConfigNames);
    
    // Check if Test_Parent_Object__c is still in the list
    const deletedConfigStillExists = finalConfigNames.some(name => name.includes('Test_Parent_Object__c'));
    
    if (!deletedConfigStillExists) {
      console.log('\n✓ Soft delete successful - Test_Parent_Object__c removed from list');
    } else {
      console.log('\n✗ Test_Parent_Object__c still appears in list');
    }
  }
  
  console.log('\nSoft delete test completed');
  
  await browser.close();
})();