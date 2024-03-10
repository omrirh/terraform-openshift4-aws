locals {
  major_version   = join(".", slice(split(".", var.openshift_version), 0, 2))
  aws_azs         = (var.aws_azs != null) ? var.aws_azs : tolist([join("",[var.aws_region,"a"]),join("",[var.aws_region,"b"]),join("",[var.aws_region,"c"])])
  
  decoded_images  = jsondecode(data.http.images.body)
  architectures   = lookup(local.decoded_images, "architectures")
  x86_64          = lookup(local.architectures, "x86_64")
  images          = lookup(local.x86_64, "images")
  aws_images      = lookup(local.images, "aws")
  regions         = lookup(local.aws_images, "regions")
  region_image    = lookup(local.regions, var.aws_region)
  rhcos_image     = lookup(local.region_image, "image")
}

data "http" "images" {
  url = "https://raw.githubusercontent.com/openshift/installer/release-${local.major_version}/data/data/coreos/rhcos.json"
  request_headers = {
    Accept = "application/json"
  }
}

