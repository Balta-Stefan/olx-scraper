# A simple web scraper that scrapes the website [olx.ba](https://olx.ba). 

It performs the following:
- fetches articles from the given URL
- compares them to previously seen articles which are stored on S3
- sends an email notification for all the new articles using Gmail SDK
- stores all the seen articles into S3