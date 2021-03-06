(in-package #:house/test)

(tests

 (subtest
  "parse-param-string"
  (is '((:a . "1")) (parse-param-string "a=1"))
  (is '((:a . "1") (:b . "2")) (parse-param-string "a=1&b=2"))
  (is '((:longer . "parameter names") (:look . "something like this"))
      (parse-param-string "longer=parameter names&look=something like this"))
  (is '((:longer . "parameter%20names") (:look . "something%20like%20this"))
      (parse-param-string "longer=parameter%20names&look=something%20like%20this")))

 (subtest
  "Request parsing"
  (subtest
   "Older HTTP versions"
   (is-error
    (parse-request-string "GET /index.html HTTP/0.9
Host: www.example.com

")
    'http-assertion-error)
   (is-error
    (parse-request-string "GET /index.html HTTP/1.0
Host: www.example.com

")
    'http-assertion-error))

  (subtest
   "Vanilla GET"
   (let ((req (parse-request-string "GET /index.html HTTP/1.1
Host: www.example.com

")))
     (is "/index.html" (resource req))
     (is '((:host . "www.example.com")) (headers req))))

  (subtest
   "GET with params"
   (let ((req (parse-request-string "GET /index.html?test=1 HTTP/1.1
Host: www.example.com

")))
     (is "/index.html" (resource req))
     (is '((:host . "www.example.com")) (headers req))
     (is '(:test . "1") (assoc :test (parameters req)))))

  (subtest
   "POST with body"
   (let ((req (parse-request-string "POST /index.html HTTP/1.1
Host: www.example.com
Content-length: 6

test=1
")))
     (is "/index.html" (resource req))
     (is '((:host . "www.example.com")) (headers req))
     ;; (is '(:test . "1") (assoc :test (parameters req)))
     ))

  (subtest
   "POST with parameters and body"
   (let ((req (parse-request-string "POST /index.html?get-test=get HTTP/1.1
Host: www.example.com
Content-length: 14

post-test=post
")))
     (is "/index.html" (resource req))
     (is '((:host . "www.example.com")) (headers req))
     (is '(:get-test . "get") (assoc :get-test (parameters req)))
     ;; (is '(:post-test . "post") (assoc :post-test (parameters req)))
     ))))
