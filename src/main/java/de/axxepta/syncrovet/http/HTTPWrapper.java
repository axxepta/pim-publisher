package de.axxepta.syncrovet.http;

import java.io.*;

import de.axxepta.syncrovet.conversion.JsonXml;
import org.apache.http.Header;
import org.apache.http.StatusLine;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.*;
import org.apache.http.entity.ContentType;
import org.apache.http.HttpEntity;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;


public class HTTPWrapper {

    public static String get(String protocol, String host, int port, String path, String user, String password) {
        CloseableHttpClient httpClient = getClient(host, port, user, password);
        try {
            HttpGet httpget = new HttpGet(protocol + "://" + host + ":" + Integer.toString(port) + path);
            try (CloseableHttpResponse response = httpClient.execute(httpget))
            {
                StatusLine statusLine = response.getStatusLine();
                int responseCode = statusLine.getStatusCode();
                if (responseCode >= 400) {
                    return "{ \"success\" : false, \"status\" : " + responseCode + ", \"error\" : \"" + statusLine.getReasonPhrase() + "\" }";
                } else {
                    return EntityUtils.toString(response.getEntity());
                }
            }
        } catch (IOException ex) {
			return ex.getMessage();
		} finally {
			try {
				httpClient.close();
			} catch (IOException ix) {}
        }
    }


    public static String getXmlFromJSON(String protocol, String host, int port, String path, String user, String password) {
        String str = get(protocol, host, port, path, user, password);
        return "<response>" + JsonXml.JsonToXmlString(str) + "</response>";
    }


    public static String postXmlToJson(String protocol, String host, int port, String path, String user, String password, String content) {
        String jsonString = JsonXml.XmlToJsonString(content);
        return postJSON(protocol, host, port, path, user, password, jsonString);
    }


    public static String postJSON(String protocol, String host, int port, String path, String user, String password, String content) {
        return post(protocol, host, port, path, user, password, content, ContentType.APPLICATION_JSON);
    }


    public static String postXML(String protocol, String host, int port, String path, String user, String password, String content) {
        return post(protocol, host, port, path, user, password, content, ContentType.APPLICATION_XML);
    }


    public static String post(String protocol, String host, int port, String path, String user, String password, String content, ContentType contentType) {
        try (CloseableHttpClient httpClient = getClient(host, port, user, password)) {
            HttpPost httpPost = new HttpPost(protocol + "://" + host + ":" + Integer.toString(port) + path);
            HttpEntity stringEntity = new StringEntity(content, contentType);
            httpPost.setEntity(stringEntity);
            try (CloseableHttpResponse response = httpClient.execute(httpPost))
            {
                return EntityUtils.toString(response.getEntity());
            }
        } catch (IOException ex) {
            return ex.getMessage();
        }
    }


    public static String putJSON(String protocol, String host, int port, String path, String user, String password, String content) {
        return put(protocol, host, port, path, user, password, content, ContentType.APPLICATION_JSON);
    }


    public static String putXML(String protocol, String host, int port, String path, String user, String password, String content) {
        return put(protocol, host, port, path, user, password, content, ContentType.APPLICATION_XML);
    }

	
    public static String put(String protocol, String host, int port, String path, String user, String password, String content, ContentType contentType) {
		CloseableHttpClient httpClient = getClient(host, port, user, password);
        try {
            HttpPut httpPut = new HttpPut(protocol + "://" + host + ":" + Integer.toString(port) + path);
			HttpEntity stringEntity = new StringEntity(content, contentType);
			httpPut.setEntity(stringEntity);
            try (CloseableHttpResponse response = httpClient.execute(httpPut))
            {
                return EntityUtils.toString(response.getEntity());
            }
        } catch (IOException ex) {
			return ex.getMessage();
		} finally {
			try {
				httpClient.close();
			} catch (IOException ix) {}
        }
    }


    public static String delete(String protocol, String host, int port, String path, String user, String password) {
        CloseableHttpClient httpClient = getClient(host, port, user, password);
        try {
            HttpDelete httpDelete = new HttpDelete(protocol +"://" + host + ":" + Integer.toString(port) + path);
            httpDelete.setHeader("Accept", "application/json");
            try (CloseableHttpResponse response = httpClient.execute(httpDelete))
            {
                return EntityUtils.toString(response.getEntity());
            }
        } catch (IOException ex) {
            return ex.getMessage();
        } finally {
            try {
                httpClient.close();
            } catch (IOException ix) {}
        }
    }


    public static String delete(String protocol, String host, int port, String path, String user, String password, String content) {
        CloseableHttpClient httpClient = getClient(host, port, user, password);
        String[] restResponse = new String[2];
        try {
            HttpDeleteWithBody httpDelete =
                    new HttpDeleteWithBody(protocol + "://" + host + ":" + Integer.toString(port) + path);
            httpDelete.setHeader("Accept", "application/json");
            StringEntity stringEntity = new StringEntity(content, ContentType.APPLICATION_JSON);
            httpDelete.setEntity(stringEntity);
            Header requestHeaders[] = httpDelete.getAllHeaders();
            try (CloseableHttpResponse response = httpClient.execute(httpDelete))
            {
                restResponse[0] = Integer.toString((response.getStatusLine().getStatusCode()));
                restResponse[1] = EntityUtils.toString(response.getEntity());
                return restResponse[1];
            }
        } catch (IOException ex) {
            return ex.getMessage();
        } finally {
            try {
                httpClient.close();
            } catch (IOException ix) {}
        }
    }
	
	
	private static CloseableHttpClient getClient(String host, int port, String user, String password) {
	int timeout = 600;
    RequestConfig config = RequestConfig.custom()
      .setConnectTimeout(timeout * 1000)
      .setConnectionRequestTimeout(timeout * 1000)
      .setSocketTimeout(timeout * 1000).build();
		CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
        credentialsProvider.setCredentials(
				new AuthScope(host, port),
                new UsernamePasswordCredentials(user, password));
        return HttpClients.custom()
                .setDefaultCredentialsProvider(credentialsProvider)
                .setDefaultRequestConfig(config)
                //.setSSLSocketFactory()

                //HACK:
                // true if it's OK to retry non-idempotent requests that have been sent
                // and then fail with network issues (not HTTP failures).
                //
                // "true" here will retry POST requests which have been sent but where
                // the response was not received. This arguably is a bit risky.
                .setRetryHandler(new DefaultHttpRequestRetryHandler(3, true))
                .build();
	}
}
