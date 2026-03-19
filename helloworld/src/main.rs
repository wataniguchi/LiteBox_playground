use axum::{extract::ConnectInfo, routing::get, Router};
use std::net::SocketAddr;
use tokio::net::TcpListener;

async fn handler_root(ConnectInfo(addr): ConnectInfo<SocketAddr>) -> String {
    let client_ip = addr.ip();
    println!("Received request from IP: {}", client_ip);
    format!("Hello, World! Your IP: {}", client_ip)
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(handler_root));

    let listener = TcpListener::bind("10.0.0.2:3000").await.unwrap();
    println!("Server is running on http://10.0.0.2:3000");
    axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>()).await.unwrap();
}