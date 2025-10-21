# Use the official NGINX image
FROM nginx:latest

# Copy website files into NGINX's default directory
COPY . /usr/share/nginx/html

# Expose port 80 for web traffic
EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
