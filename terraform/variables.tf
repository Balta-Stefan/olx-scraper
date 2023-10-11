variable "aws_access_key" {
  type = string
  sensitive = true
}

variable "aws_secret_key" {
  type = string
  sensitive = true
}

variable "receiver_email" {
  type = string
}

variable "links_bucket" {
  type = string
}

variable "scrape_url" {
  type = string
}