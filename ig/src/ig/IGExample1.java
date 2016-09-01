package ig;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.net.ssl.HttpsURLConnection;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

import com.lightstreamer.client.ClientListener;
import com.lightstreamer.client.ItemUpdate;
import com.lightstreamer.client.LightstreamerClient;
import com.lightstreamer.client.Subscription;
import com.lightstreamer.client.SubscriptionListener;
import com.lightstreamer.log.LoggerProvider;

/**
 * @author alanwhite
 * 
 * Example code to retrieve list of markets on IG in watchlist "Major FX", create a thread for each and feed 
 * those threads realtime tick data.
 * 
 * Status: Experimental
 *
 */
public class IGExample1 implements LoggerProvider {

	private static Logger logger = Logger.getLogger(IGExample1.class.getName());
	
	/*
	 * Identify which platform, live or demo
	 */
	private String IGHost = null;
	
	/*
	 * Returned by IG API on successful authentication
	 */
	private String IGCST = null;
	private String IGSecToken = null;
	private String clientID = null;

	/*
	 * Where to connect to for the streaming data
	 */
	private String lightstreamerEndpoint = null;
	
	/*
	 * Which watchlist to monitor
	 */
	private final String mmWatchlist = "Major FX";
	
	private List<String> mmEpics = new ArrayList<String>();
	
	/*
	 * TEMPORARY: our credentials
	 */
	private String IG_USERNAME = "ENTER YOURS";
	private String IG_PASSWORD = "ENTER YOURS";
	private String IG_API_KEY = "ENTER YOURS";
	
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		
		// TODO: add command line switch to determine prod/demo
		new IGExample1("https://demo-api.ig.com");
	}
	
	/*
	 * Constructor ...
	 */
	IGExample1(String host) {
		
		logger.setLevel(Level.ALL);
		LightstreamerClient.setLoggerProvider(this);
		
		IGHost = host;
		if ( !login(IGHost, IG_USERNAME, IG_PASSWORD, IG_API_KEY) ) {
			System.out.println("Connection failed");
			return;
		}
		
		// obtain list of instruments in well known watchlist
		try {
			setupMarketList();
			monitorMarkets();
			
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			logout();
		}
	}
	
	/**
	 * Prints price updates from markets in mmEpics list
	 */
	private void monitorMarkets() {

		LightstreamerClient lsc = new LightstreamerClient(lightstreamerEndpoint, null);
		lsc.connectionDetails.setUser(clientID);
		lsc.connectionDetails.setPassword("CST-"+IGCST+"|XST-"+IGSecToken);
		lsc.addListener(new ClientListener() {

			@Override
			public void onListenEnd(LightstreamerClient arg0) {
				System.out.println("onListenEnd");
				
			}

			@Override
			public void onListenStart(LightstreamerClient arg0) {
				System.out.println("onListenStart");
				
			}

			@Override
			public void onPropertyChange(String arg0) {
				System.out.println("onPropertyChange");
				
			}

			@Override
			public void onServerError(int arg0, String arg1) {
				System.out.println("onServerError");
				
			}

			@Override
			public void onStatusChange(String arg0) {
				// TODO Auto-generated method stub
				System.out.println("onStatusChange");
			}
			
		});
			
		lsc.connect();
		
		Map<String,MarketQueue> markets = new HashMap<String,MarketQueue>();
		List<String> itemsList = new ArrayList<String>();
		
		for ( String market : mmEpics ) {
			String item = "MARKET:"+market;
			itemsList.add(item);
			
			MarketQueue mq = new MarketQueue();
			markets.put(item, mq);
			
			Thread mw = new Thread(new MarketWatcher(market,mq));
			mw.start();
		}
		
		String[] items = (String[]) itemsList.toArray(new String[0]);
		String[] fields = {"BID", "OFFER"};
		Subscription sub = new Subscription("MERGE",items,fields);
		
		sub.addListener(new SubscriptionListener() {

			@Override
			public void onClearSnapshot(String arg0, int arg1) {
				System.out.println("onClearSnapshot");
				
			}

			@Override
			public void onCommandSecondLevelItemLostUpdates(int arg0,
					String arg1) {
				System.out.println("onCommandSecondLevelItemLostUpdates");
				
			}

			@Override
			public void onCommandSecondLevelSubscriptionError(int arg0,
					String arg1, String arg2) {
				System.out.println("onCommandSecondLevelSubscriptionError");
				
			}

			@Override
			public void onEndOfSnapshot(String arg0, int arg1) {
				System.out.println("onEndOfSnapshot");
				
			}

			@Override
			public void onItemLostUpdates(String arg0, int arg1, int arg2) {
				System.out.println("onItemLostUpdates");
				
			}

			@Override
			public void onItemUpdate(ItemUpdate arg0) {
				MarketQueue mq = markets.get(arg0.getItemName());
				try {
					mq.put(arg0);
				} catch (InterruptedException e) {
					logger.log(Level.SEVERE, "Unable to foward item update "+arg0);
					e.printStackTrace();
				}
				
			}

			@Override
			public void onListenEnd(Subscription arg0) {
				System.out.println("onListenEnd");
				
			}

			@Override
			public void onListenStart(Subscription arg0) {
				System.out.println("onListenStart");
				
			}

			@Override
			public void onSubscription() {
				System.out.println("onSubscription");
				
			}

			@Override
			public void onSubscriptionError(int arg0, String arg1) {
				System.out.println("onSubscriptionError");
				
			}

			@Override
			public void onUnsubscription() {
				System.out.println("onUnsubscription");
				
			}
			
		});
		
		lsc.subscribe(sub);
		try {
			Thread.sleep(5000);
		} catch (InterruptedException e) {
			logger.log(Level.SEVERE, "sleep interrupted", e);
			e.printStackTrace();
		}
		
	}
	
	/**
	 * Populate the list of markets we're to watch
	 * @throws Exception if unable to obtain the list of markets from IG
	 */
	private void setupMarketList() throws Exception {
		try {
			URL sessionURL = new URL(IGHost+"/gateway/deal/watchlists");
			
			if (sessionURL != null) {

				HttpsURLConnection connection = (HttpsURLConnection) sessionURL.openConnection();
				connection.setRequestMethod("GET");
				connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
				connection.setRequestProperty("Accept", "application/json; charset=UTF-8");
				connection.setRequestProperty("X-IG-API-KEY", IG_API_KEY);
				connection.setRequestProperty("CST", IGCST);
				connection.setRequestProperty("X-SECURITY-TOKEN", IGSecToken);
				
				connection.connect();
				
				int responseCode = connection.getResponseCode();
				if ( responseCode != HttpsURLConnection.HTTP_OK) {
					System.out.println("logout error "+connection.getHeaderFields());
					throw(new Exception("failed to obtain list of watchlists from IG"));
				}

			    JSONParser parser = new JSONParser();
				JSONObject contentJSON = (JSONObject) parser.parse(new InputStreamReader(connection.getInputStream()));
				JSONArray watchlistsJSON = (JSONArray) contentJSON.get("watchlists");
				Iterator<JSONObject> iterator = watchlistsJSON.iterator();
				while (iterator.hasNext()) {
					JSONObject watchlistJSON = iterator.next();
					String wlName = (String) watchlistJSON.get("name");
					if ( wlName.equalsIgnoreCase(mmWatchlist)) {
						String wlId = (String) watchlistJSON.get("id");
						setupMarketList(wlId);
					}
				}
				
				
			}
			
		} catch (MalformedURLException e) {
			System.out.println("unable to parse IG watchlists URL");
			e.printStackTrace();
		} catch (IOException e) {
			System.out.println("error connecting to get list of markets to watch");
			e.printStackTrace();
		} 
	}
	
	/**
	 * Populate the list of markets we're to watch from the watchlist id provided
	 * @param id the watchlist Id as returned by IG in the list watchlists API call
	 * @throws Exception if unable to obtain the list of markets from IG
	 */
	private void setupMarketList(String id) throws Exception {
		try {
			URL sessionURL = new URL(IGHost+"/gateway/deal/watchlists/"+id);
			URI uri = new URI(sessionURL.getProtocol(), 
					sessionURL.getUserInfo(), 
					sessionURL.getHost(), 
					sessionURL.getPort(), 
					sessionURL.getPath(), 
					sessionURL.getQuery(),
					sessionURL.getRef());
			sessionURL = uri.toURL();
			
			if (sessionURL != null) {

				HttpsURLConnection connection = (HttpsURLConnection) sessionURL.openConnection();
				connection.setRequestMethod("GET");
				connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
				connection.setRequestProperty("Accept", "application/json; charset=UTF-8");
				connection.setRequestProperty("X-IG-API-KEY", IG_API_KEY);
				connection.setRequestProperty("CST", IGCST);
				connection.setRequestProperty("X-SECURITY-TOKEN", IGSecToken);
				
				connection.connect();
				
				int responseCode = connection.getResponseCode();
				if ( responseCode != HttpsURLConnection.HTTP_OK) {
					System.out.println("logout error "+connection.getHeaderFields());
					throw(new Exception("failed to obtain list of markets from watchlist from IG"));
				}

			    JSONParser parser = new JSONParser();
				JSONObject contentJSON = (JSONObject) parser.parse(new InputStreamReader(connection.getInputStream()));
				JSONArray marketsJSON = (JSONArray) contentJSON.get("markets");
				Iterator<JSONObject> iterator = marketsJSON.iterator();
				while (iterator.hasNext()) {
					JSONObject marketJSON = iterator.next();
					String epicName = (String) marketJSON.get("epic");
					String instrumentName = (String) marketJSON.get("instrumentName");
					System.out.println("Epic:"+epicName+", Instrument:"+instrumentName);
					mmEpics.add(epicName);
				}
				
			}
			
		} catch (MalformedURLException e) {
			System.out.println("unable to parse IG watchlist URL");
			e.printStackTrace();
		} catch (IOException e) {
			System.out.println("error connecting to get list of markets to watch");
			e.printStackTrace();
		} 
	}
	
	/**
	 * explicitly logs out of an IG session, thus cancelling the security token
	 */
	private void logout() {
		try {
			URL sessionURL = new URL(IGHost+"/gateway/deal/session");
			
			if (sessionURL != null) {

				HttpsURLConnection connection = (HttpsURLConnection) sessionURL.openConnection();
				connection.setRequestMethod("DELETE");
				connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
				connection.setRequestProperty("Accept", "application/json; charset=UTF-8");
				connection.setRequestProperty("X-IG-API-KEY", IG_API_KEY);
				connection.setRequestProperty("CST", IGCST);
				connection.setRequestProperty("X-SECURITY-TOKEN", IGSecToken);
				
				connection.connect();
				
				int responseCode = connection.getResponseCode();
				if ( responseCode != HttpsURLConnection.HTTP_NO_CONTENT) {
					System.out.println("logout error "+connection.getHeaderFields());
				}

			}
			
		} catch (MalformedURLException e) {
			System.out.println("unable to parse IG session URL");
			e.printStackTrace();
		} catch (IOException e) {
			System.out.println("error connecting to logout");
			e.printStackTrace();
		} 
	}

	/**
	 * Connects and authenticates with IG
	 * @param IGURL string representing the webserver to connect to, no trailing slash, eg 'https://demo-api.ig.com'
	 * @param userName
	 * @param passWord
	 * @param APIKey
	 * @return true if successful
	 */
	private boolean login(String IGURL, String userName, String passWord, String APIKey) {
		
		try {
			URL sessionURL = new URL(IGURL+"/gateway/deal/session");
			
			if (sessionURL != null) {

				List<String> params = new ArrayList<String>();
				JSONObject requestBody = new JSONObject();
				requestBody.put("identifier", IG_USERNAME);
				requestBody.put("password", IG_PASSWORD);
	
				HttpsURLConnection connection = (HttpsURLConnection) sessionURL.openConnection();
				connection.setRequestMethod("POST");
				connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
				connection.setRequestProperty("Accept", "application/json; charset=UTF-8");
				connection.setRequestProperty("X-IG-API-KEY", IG_API_KEY);
				
				connection.setDoOutput(true);

				OutputStreamWriter out=null;
				out = new OutputStreamWriter(connection.getOutputStream());
				out.write(requestBody.toJSONString());
				out.close();
				
				int responseCode = connection.getResponseCode();
				if ( responseCode != HttpsURLConnection.HTTP_OK) {
					System.out.println("error "+connection.getHeaderFields());
					return false;
				}

				IGCST = connection.getHeaderField("cst");
				IGSecToken = connection.getHeaderField("x-security-token");
				
			    JSONParser parser = new JSONParser();
				JSONObject contentJSON = (JSONObject) parser.parse(new InputStreamReader(connection.getInputStream()));
				lightstreamerEndpoint = (String) contentJSON.get("lightstreamerEndpoint"); 
				clientID = (String) contentJSON.get("clientId"); 
				System.out.println("Client ID: "+clientID);
				
				return true;
			}
			
		} catch (MalformedURLException e) {
			System.out.println("unable to parse IG session URL");
			e.printStackTrace();
		} catch (IOException e) {
			System.out.println("error connecting");
			e.printStackTrace();
		} catch (ParseException e) {
			System.out.println("can't understand content of reply from IG");
			e.printStackTrace();
		} 
		
		return false;
	}

	@SuppressWarnings("serial")
	class MarketQueue extends ArrayBlockingQueue<Object> {

		public MarketQueue() {
			super(9);
			// 9 entries in this queue
		}

	}
	
	class MarketWatcher implements Runnable {

		MarketQueue queue;
		String threadName;
		
		public MarketWatcher(String name, MarketQueue pQueue) {
			queue = pQueue;
			threadName = name;
		}
		
		@Override
		public void run() {
			Thread.currentThread().setName(threadName);
			System.out.println(threadName+" thread started");
			
			for (;;) {
				try {
					Object obj = queue.take();
					
					if ( obj instanceof ItemUpdate ) {
						System.out.println(threadName + ": tick");
					} else {
						System.out.println(threadName + ": funny message");
					}
					
				} catch (InterruptedException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
					continue;
				}
			}
		}
		
	}
	
	@Override
	public com.lightstreamer.log.Logger getLogger(String category) {
		return new MyLogger();
	}

	class MyLogger implements com.lightstreamer.log.Logger {

		@Override
		public void debug(String line) {
			logger.log(Level.FINEST, line);
			
		}

		@Override
		public void debug(String line, Throwable exception) {
			logger.log(Level.FINEST, line + exception.getMessage());
			
		}

		@Override
		public void error(String line) {
			logger.log(Level.SEVERE, line);
			
		}

		@Override
		public void error(String line, Throwable exception) {
			logger.log(Level.SEVERE, line + exception.toString());
			
		}

		@Override
		public void fatal(String line) {
			logger.log(Level.ALL, line);
			
		}

		@Override
		public void fatal(String line, Throwable exception) {
			logger.log(Level.ALL, line + exception.toString());
			
		}

		@Override
		public void info(String line) {
			logger.log(Level.INFO, line);
			
		}

		@Override
		public void info(String line, Throwable exception) {
			logger.log(Level.INFO, line + exception.toString());
			
		}

		@Override
		public boolean isDebugEnabled() {
			return true;
		}

		@Override
		public boolean isErrorEnabled() {
			return true;
		}

		@Override
		public boolean isFatalEnabled() {
			return true;
		}

		@Override
		public boolean isInfoEnabled() {
			return true;
		}

		@Override
		public boolean isWarnEnabled() {
			return true;
		}

		@Override
		public void warn(String line) {
			logger.log(Level.WARNING, line);
			
		}

		@Override
		public void warn(String line, Throwable exception) {
			logger.log(Level.WARNING, line + exception.toString());
			
		}
		
	}
}

