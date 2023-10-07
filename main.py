import logging
import os
import re
import time

from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.chrome.options import ChromiumOptions
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.core.os_manager import ChromeType

import gmail_utils
import aws_utils

'''
    Environment variables:
      - RECEIVER - email address which receives the notifications
      - LINKS_BUCKET - bucket which holds a file that specifies all the previously seen articles
      - SCRAPE_URL - URL to scrape
      - BROWSER_PATH - path of the browser executable
      - BROWSER_DRIVER_VERSION - version of the browser driver
'''


def save_to_file(file_path, content):
    with open(file_path, 'w') as file:
        file.write(content)


def notify_about_new_articles(new_articles):
    receiver = os.getenv("RECEIVER")

    oauth_creds = aws_utils.get_parameter_from_parameter_store("/olx-scraper/gmail-api-credentials", True)
    creds = gmail_utils.obtain_gmail_credentials(oauth_creds)
    message = '\n'.join(new_articles)
    gmail_utils.gmail_send_message(creds, message, receiver, "New OLX articles notification")


def load_old_articles():
    links = []
    if aws_utils.download_file(links_object_name, bucket):
        with open(links_object_name, 'r') as file:
            for line in file:
                links.append(line.strip())

    return links


links_object_name = "links.txt"

bucket = os.getenv("LINKS_BUCKET")
old_articles = load_old_articles()
if len(old_articles) == 0:
    logging.info("Haven't found any old articles in the S3 object.")

url = os.getenv("SCRAPE_URL")

brave_path = os.getenv("BROWSER_PATH")

options = ChromiumOptions()
options.binary_location = brave_path
options.add_argument("--headless")
options.add_argument('--disable-gpu')
options.add_argument("--disable-extensions")

# Disable images
prefs = {
    "profile.managed_default_content_settings.images": 2  # 2 means block images
}
options.add_experimental_option("prefs", prefs)


driver = webdriver.Chrome(
    service=Service(
        ChromeDriverManager(driver_version=os.getenv("BROWSER_DRIVER_VERSION"), chrome_type=ChromeType.BRAVE).install()
    )
    , options=options
)

driver.set_page_load_timeout(10)
driver.set_script_timeout(10)
driver.implicitly_wait(10)


href_pattern = re.compile(r'/artikal/[0-9]+')

try:
    driver.get(url)
except TimeoutException as e:
    print("Page load timeout occurred. Refreshing.")
    driver.refresh()

links = []
try:
    links = driver.find_elements(By.TAG_NAME, "a")
except TimeoutException as te:
    print("Couldn't get <a> tags from the page. ", te)
    time.sleep(5)
    driver.refresh()

replacement_articles = []
new_articles = []
found_new = False

for link in links:
    href = link.get_attribute("href")
    if re.search(r'/artikal/[0-9]+', href):
        print(href)
        replacement_articles.append(href)
        if href not in old_articles:
            found_new = True
            new_articles.append(href)


if found_new:
    notify_about_new_articles(new_articles)

    save_to_file(links_object_name, '\n'.join(new_articles))
    aws_utils.upload_file(links_object_name, bucket)


# while True:
#     sleep_time = random.randrange(4, 10)
#     try:
#         links = driver.find_elements(By.TAG_NAME, "a")
#     except TimeoutException as te:
#         print("Couldn't get <a> tags from the page. ", te)
#         time.sleep(sleep_time)
#         driver.refresh()
#         continue
#
#     temp_articles = {}
#     new_articles = []
#     found_new = False
#
#     for link in links:
#         href = link.get_attribute("href")
#         if re.search(r'/artikal/[0-9]+', href):
#             print(href)
#             temp_articles[href] = True
#             if len(found_articles) > 0 and found_articles.get(href) is None:
#                 print("Found new article: ", href)
#                 found = True
#                 new_articles.append(href)
#     found_articles = temp_articles.copy()
#     if found_new:
#         notify_about_new_articles(new_articles)
#
#     time.sleep(sleep_time)
#     driver.refresh()

#driver.quit()