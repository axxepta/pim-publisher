package de.axxepta.syncrovet.daemon;

public class RequestDaemon<T> extends Thread {


    private String host;
    private int port;
    private String path;
    private String user;
    private String password;
    private T payload;
    private String[] parameters;
    private long updateInterval;
    private RequestFunction func;

    public RequestDaemon(String host, int port, String path, String user, String password,
               T payload, String[] parameters, long updateInterval, RequestFunction func){
        this.host = host;
        this.port = port;
        this.path = path;
        this.user = user;
        this.password = password;
        this.payload = payload;
        this.parameters = parameters;
        this.updateInterval = updateInterval;
        this.func = func;
        setDaemon(true);
        start();
    }

    @Override
    public void run() {
        try {
            while (!isInterrupted()) {
                func.exec(host, port, path, user, password, payload, parameters);
                Thread.sleep(updateInterval);
            }
        } catch (Exception ex) { }
    }
}
