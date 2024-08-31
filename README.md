# Cloud Eater

This is an app you can build and install on an iOS device to help _**eat**_ up space in a iCloud account. Why would you want to do that? Well, for those times when you want to verify how the app you are developing or debugging behaves under conditions of low iCloud space availability. 

* Debugging iCloud space related issues is hard, so use this tool to help your efforts but don't expect it to magically find your issues on its own.

* This tool applies to a user's private database

* When there is no more space available CloudKit will return an QUOTA_EXCEEDED error

**USE AT YOUR OWN RISK!**
If everything is not working on the device as expected there is a chance you may brick it. I've not seen that happen, but please be forewarned. 
<br>

<p align=center>
<img src='/Images/Screenshot1.png' width='250' border='0' alt='A screenshot of the primary screen of the app' />
</p>

### Usage

1. Set the bundle identifier in the downloaded project

2. Make sure your phone is signed into an iCloud account

3. Build and run the app - this will likely result in an error because even though the database schema is created on-the-fly there is no way to programmatically define the required indexes

4. In a web browser, sign into your development account's <a href='https://developer.apple.com/icloud/cloudkit'>CloudKit dashboard</a> and navigate to the index tab for this app's container
<p align=center>
<img src='/Images/Screenshot2.png' width='250' border='0' alt='A screenshot of the CloudKit dashboard' />
</p>

5. Add a queryable index called recordName for the _recordID_ field

6. Add a sortable index called createdTimestamp for the _createTime_ field


### Notes

* You will notice that unlike the <a href='https://github.com/hotngui/SpaceEater'>Space Eater</a> app, _Cloud Eater_ does not display the total amount of space available or the amount of space being used by other apps. This is because the is no **CloudKit** API to retrieve that information.

* For simplicity and safety you probably want to use an iCloud account other than your own. You can create an account and it gets 5GB of iCloud space for free. If you do this you will to make sure that when on the CloudKit dashboard you select the _Act as iCloud Account..._ command. This let's you view/query the data in that account's private database.

* Keep in mind that many things can use up iCloud space including but not limited to Backups, iCloud Photos, and other apps.

<br>
If you want to support my work, you can by me a coke zero... <br><br>

<a href='https://ko-fi.com/F1F4UHD6J' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coke Zero	 at ko-fi.com' /></a>

