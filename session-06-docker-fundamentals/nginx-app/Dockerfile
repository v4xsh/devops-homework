# Official Nginx image (Alpine variant)
FROM nginx:alpine

# Replace the default welcome page with our Hello World page
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

# Run nginx in the foreground so the container keeps running
CMD ["nginx", "-g", "daemon off;"]
