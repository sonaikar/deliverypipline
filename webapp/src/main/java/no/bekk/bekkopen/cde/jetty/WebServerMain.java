package no.bekk.bekkopen.cde.jetty;

import java.io.File;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.TimeZone;

import no.bekk.bekkopen.cde.jetty.config.MySelectChannelConnector;
import no.bekk.bekkopen.cde.jetty.config.MyWebAppContext;
import no.bekk.bekkopen.cde.jetty.config.SystemPropertiesLoader;

import org.apache.commons.io.FileUtils;
import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.HandlerCollection;
import org.eclipse.jetty.util.RolloverFileOutputStream;
import org.eclipse.jetty.webapp.WebAppContext;

public class WebServerMain {

	private static final String UNABLE_TO_START = "Unable to start";
	private static final String UNABLE_TO_STOP = "Unable to stop";

	private static final String SESSION_PATH = "/";

	// Graceful shutdown timeout
	private static final int GRACEFUL_SHUTDOWN = 1000;
	// Jetty server
	private static Server jettyServer;
	private static int port;

	public static void main(final String[] args) throws Exception {
		start();
	}

	private static void start() {
		if (!"true".equals(System.getProperty("dev"))) {
			configureLogging();
		}
		if (jettyServer != null && jettyServer.isRunning()) {
			System.out.println("Called JettyServer.start(), but the server is allready started.");
			return;
		}
		configure();
		try {
			jettyServer.start();
		} catch (final Exception e) {
			throw new RuntimeException(UNABLE_TO_START, e);
		}
		port = jettyServer.getConnectors()[0].getLocalPort();
		System.out.println("JettyServer started on http://" + System.getProperty("hostname", "localhost") + ":" + port + SESSION_PATH);
	}

	private static void configure() {
		try {
			SystemPropertiesLoader.loadWebConfig();
			SystemPropertiesLoader.loadSecrets();
		} catch (final Exception e) {
			throw new RuntimeException(UNABLE_TO_START, e);
		}

		jettyServer = new Server();

		jettyServer.setConnectors(new Connector[] { new MySelectChannelConnector() });

		List<Handler> handlerList = new ArrayList<Handler>();
		
		String webApp;
		if ("true".equals(System.getProperty("run.exploded"))) {
			webApp = "src/main/webapp";
		} else {
			webApp = findPathToWarFile(new File(System.getProperty("basedir", "target")));
		}
		
		WebAppContext context = new MyWebAppContext(webApp, SESSION_PATH);
		handlerList.add(context);
		
		final HandlerCollection handlers = new HandlerCollection();
		handlers.setHandlers(handlerList.toArray(new Handler[handlerList.size()]));

		jettyServer.setHandler(handlers);
		jettyServer.setGracefulShutdown(GRACEFUL_SHUTDOWN);
		jettyServer.setStopAtShutdown(true);
	}

	private static void configureLogging() {
		try {
			File logDir = new File(System.getProperty("jetty.home", "../logs"));
			logDir.mkdir();
			final String logName = logDir.getAbsolutePath() + "/stderrout.yyyy_mm_dd.log";
			RolloverFileOutputStream logFile = new RolloverFileOutputStream(logName, false, 90, TimeZone.getTimeZone("GMT+1"));
			final PrintStream serverLog = new PrintStream(logFile);
			System.setOut(serverLog);
			System.setErr(serverLog);
		} catch (final Exception e) {
			throw new RuntimeException(UNABLE_TO_START + ": Unable to configure logging: " + e);
		}

	}

	private static String findPathToWarFile(final File repoDir) {
		if (repoDir.canRead()) {
			final Collection<File> files = FileUtils.listFiles(repoDir, new String[] { "war" }, true);
			if (1 == files.size()) {
				for (final File warFile : files) {
					return warFile.getAbsolutePath();
				}
			} else {
				final StringBuilder msg = new StringBuilder("Expected 1 webapp (.war) in: ");
				msg.append(repoDir.getAbsolutePath());
				msg.append(". Found " + files.size());
				throw new RuntimeException(UNABLE_TO_START + msg.toString());
			}
		}
		System.err.println(UNABLE_TO_START + ": Can't read: " + repoDir.getAbsolutePath());
		throw new RuntimeException(UNABLE_TO_START + ": Can't read: " + repoDir.getAbsolutePath());
	}

	private WebServerMain() {
	}

	public static Server getJettyServer() {
		return jettyServer;
	}

}
