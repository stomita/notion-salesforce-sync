// UI test script for soft delete functionality
const puppeteer = require('puppeteer');

async function testSoftDelete() {
    const browser = await puppeteer.launch({ headless: false });
    const page = await browser.newPage();
    
    try {
        // Login to Salesforce
        const loginUrl = 'https://power-fun-271-dev-ed.scratch.my.salesforce.com/secur/frontdoor.jsp?sid=00DHy000000eJvt!AR8AQLnii70N.RZ7JEp4oSAbgjnrr5heU4vf.EguBKIO2VJabkSTQEZ5qKwa5JKZNE67nXbcdRUmViQbusbH.kN7t7cEv69c';
        await page.goto(loginUrl);
        
        // Wait for page to load
        await page.waitForNavigation({ waitUntil: 'networkidle0' });
        
        // Navigate to Notion Sync Admin app
        await page.goto('https://power-fun-271-dev-ed.scratch.my.salesforce.com/lightning/n/Notion_Sync_Admin');
        
        // Wait for the configuration list to load
        await page.waitForSelector('lightning-accordion', { timeout: 30000 });
        
        // Check if Test_Parent_Object__c is in the list
        const configurations = await page.evaluate(() => {
            const accordionItems = document.querySelectorAll('lightning-accordion-section');
            const configs = [];
            accordionItems.forEach(item => {
                const title = item.querySelector('[slot="label"]')?.textContent?.trim();
                if (title) {
                    configs.push(title);
                }
            });
            return configs;
        });
        
        console.log('Visible configurations:', configurations);
        
        // Verify Test_Parent_Object__c is NOT in the list
        const hasDeletedConfig = configurations.some(config => 
            config.includes('Test_Parent_Object__c')
        );
        
        if (!hasDeletedConfig) {
            console.log('✅ SUCCESS: Test_Parent_Object__c is NOT visible (correctly filtered out)');
        } else {
            console.log('❌ FAILURE: Test_Parent_Object__c is still visible');
        }
        
        // Take a screenshot for verification
        await page.screenshot({ path: 'notion-sync-admin-after-delete.png' });
        
    } catch (error) {
        console.error('Test failed:', error);
    } finally {
        await browser.close();
    }
}

testSoftDelete();