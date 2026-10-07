# Official Apache HTTP Server image (Alpine variant)
FROM httpd:2.4-alpine

# httpd:alpine serves files from /usr/local/apache2/htdocs/
COPY index.html /usr/local/apache2/htdocs/index.html

EXPOSE 80

# The base image already defines CMD ["httpd-foreground"]; repeated here for clarity
CMD ["httpd-foreground"]
