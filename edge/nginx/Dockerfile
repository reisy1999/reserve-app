FROM nginx:1.27.2-alpine

# Set timezone
ENV TZ=Asia/Tokyo
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone && \
    apk del tzdata

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Add healthcheck using wget (available in alpine)
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
