package de.axxepta.syncrovet.email;

import org.apache.commons.mail.*;
import org.apache.commons.mail.resolver.DataSourceUrlResolver;

import java.net.MalformedURLException;
import java.net.URL;

/**
 * Wrapper utility class for Apache commons mail (version 1.5), provides static functions for sending mails, e.g. for use in XQuery.
 * @version 0.1
 */
public class Mail {


    /**
     * Send text mail
     * @param sslTls    Use secure transport layer
     * @param host      SMTP host
     * @param port      SMTP/SSMTP port
     * @param user      User name
     * @param pwd       Password
     * @param from      Sender address
     * @param to        Recipient(s) address(es), multiple can be provided separated by comma or semicolon
     * @param subject   Subject
     * @param msg       Message
     * @return success or failed xml element, latter containing error message
     */
    public static String sendMail(boolean sslTls, String host, int port, String user, String pwd, String from,
                                  String to, String subject, String msg) {

        Email email = new SimpleEmail();
        email.setHostName(host);
        email.setSmtpPort(port);
        email.setAuthenticator(new DefaultAuthenticator(user, pwd));
        email.setSSLOnConnect(sslTls);
        email.setStartTLSEnabled(sslTls);
        try {
            email.setFrom(from);
            email.setSubject(subject);
            email.setMsg(msg);
            for (String recipient : to.split(";|,")) {
                email.addTo(recipient);
            }
            email.send();
        } catch (EmailException ex) {
            ex.printStackTrace();
            return "<failed>" + ex.getMessage() + "</failed>";
        }
        return "<success/>";
    }

    /**
     * Send HTML mail
     * @param sslTls    Use secure transport layer
     * @param host      SMTP host
     * @param port      SMTP/SSMTP port
     * @param user      User name
     * @param pwd       Password
     * @param from      Sender address
     * @param to        Recipient(s) address(es), multiple can be provided separated by comma or semicolon
     * @param subject   Subject
     * @param msg       Message
     * @param msgText   Alternative text message
     * @return success or failed xml element, latter containing error message
     */
    public static String sendHTMLMail(boolean sslTls, String host, int port, String user, String pwd, String from,
                                      String to, String subject, String msg, String msgText) {
        HtmlEmail email = new HtmlEmail();
        email.setHostName(host);
        email.setSmtpPort(port);
        email.setAuthenticator(new DefaultAuthenticator(user, pwd));
        email.setSSLOnConnect(sslTls);
        email.setStartTLSEnabled(sslTls);
        try {
            email.setFrom(from);
            email.setSubject(subject);
            email.setHtmlMsg(msg);
            email.setTextMsg(msgText);
            for (String recipient : to.split(";|,")) {
                email.addTo(recipient);
            }
            email.send();
        } catch (EmailException ex) {
            ex.printStackTrace();
            return "<failed>" + ex.getMessage() + "</failed>";
        }
        return "<success/>";
    }


    /**
     * Send HTML mail, embed images referenced by img element in body
     * @param sslTls    Use secure transport layer
     * @param host      SMTP host
     * @param port      SMTP/SSMTP port
     * @param user      User name
     * @param pwd       Password
     * @param from      Sender address
     * @param to        Recipient(s) address(es), multiple can be provided separated by comma or semicolon
     * @param subject   Subject
     * @param msg       Message
     * @param msgText   Alternative text message
     * @param baseUrl   Base URL for images to be embedded, provided with relative path
     * @return success or failed xml element, latter containing error message
     */
    public static String sendImageHTMLMail(boolean sslTls, String host, int port, String user, String pwd, String from,
                                           String to, String subject, String msg, String msgText, String baseUrl) {
        URL url;
        try {
            url = new URL(baseUrl);
        } catch (MalformedURLException ue) {
            return "<failed>" + ue.getMessage() + "</failed>";
        }

        ImageHtmlEmail email = new ImageHtmlEmail();
        email.setDataSourceResolver(new DataSourceUrlResolver(url));
        email.setHostName(host);
        email.setSmtpPort(port);
        email.setAuthenticator(new DefaultAuthenticator(user, pwd));
        email.setSSLOnConnect(sslTls);
        email.setStartTLSEnabled(sslTls);
        try {
            email.setFrom(from);
            email.setSubject(subject);
            email.setHtmlMsg(msg);
            email.setTextMsg(msgText);
            for (String recipient : to.split(";|,")) {
                email.addTo(recipient);
            }
            email.send();
        } catch (EmailException ex) {
            ex.printStackTrace();
            return "<failed>" + ex.getMessage() + "</failed>";
        }
        return "<success/>";
    }

}
