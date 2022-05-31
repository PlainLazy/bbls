
# в 3.7 не работает momoko из-за ключевого слова async
#FROM python:3.7-rc-stretch

# берем 3.6
FROM python:3.6-stretch

WORKDIR /var
COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

#COPY . .
#CMD [ "python3", "./your-daemon-or-script.py" ]