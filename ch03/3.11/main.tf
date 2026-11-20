resource "local_file" "foo" {
  content  = upper("foo!")
  filename = "${path.module}/foo.bar"
}

# templatefile: 템플릿 파일에 변수를 넣어 렌더링한다.
resource "local_file" "nginx_conf" {
  content = templatefile("${path.module}/templates/nginx.conf.tftpl", {
    port     = 80
    backends = ["10.0.20.10:5000", "10.0.21.10:5000"]
  })
  filename = "${path.module}/nginx.conf"
}

output "functions" {
  value = {
    upper      = upper("hello")
    join       = join(",", ["a", "b", "c"])
    split      = split(",", "a,b,c")
    replace    = replace("hello-world", "-", "_")
    max        = max(5, 12, 9)
    length     = length(["a", "b"])
    lookup     = lookup({ a = 1, b = 2 }, "c", 0)
    merge      = merge({ a = 1 }, { b = 2 })
    flatten    = flatten([["a"], ["b", "c"]])
    jsonencode = jsonencode({ name = "tf" })
    cidrsubnet = cidrsubnet("10.0.0.0/16", 8, 1)
    cidrhost   = cidrhost("10.0.1.0/24", 10)
    timestamp  = formatdate("YYYY-MM-DD", timestamp())
  }
}
