FROM nginx:1.27-alpine
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html oyunlar.html oyun.html hakkimizda.html iletisim.html hesap-sil.html veri-sil.html sitemap.xml robots.txt google-site-verification.txt google4dc9ddbbfcaaf83c.html /usr/share/nginx/html/
COPY css /usr/share/nginx/html/css
COPY js /usr/share/nginx/html/js
ENV PORT=8080
EXPOSE 8080
