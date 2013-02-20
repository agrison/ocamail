import smtplib, email, email.mime.application
s = smtplib.SMTP('localhost')
s.sendmail('foo@bar.com', ['a.grison@gmail.com'], 'Hello world!')

msg = email.mime.Multipart.MIMEMultipart()
msg.attach(email.mime.Text.MIMEText("Hello"))
msg.attach(email.mime.application.MIMEApplication(open('attach.txt').read())
s.sendmail('foo@bar.com', ['a.grison@gmail.com'], msg.as_string())

s.quit()