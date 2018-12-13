package de.axxepta.syncrovet.daemon;

@FunctionalInterface
public interface RequestFunction<T> {

    String exec(String host, int port, String path, String user, String password, T payload, String[] parameters);

}
