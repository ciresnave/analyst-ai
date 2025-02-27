use axum::{
    response::Html,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::process::Command;
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() {
    // Shared state for requirements document
    let requirements = Arc::new(Mutex::new(String::from(
        "# Requirements Document\n\nInitial draft.",
    )));
    let app_state = AppState {
        requirements: requirements.clone(),
    };

    // Build the Axum app
    let app = Router::new()
        .route("/", get(index))
        .route("/chat", post(handle_chat))
        .route("/requirements", get(get_requirements))
        .with_state(app_state);

    // Start server
    let listener = tokio::net::TcpListener::bind("127.0.0.1:3000")
        .await
        .unwrap();
    println!("Server running at http://127.0.0.1:3000");
    axum::serve(listener, app).await.unwrap();
}

// App state to share requirements
#[derive(Clone)]
struct AppState {
    requirements: Arc<Mutex<String>>,
}

// Serve the index.html
async fn index() -> Html<String> {
    Html(include_str!("../static/index.html").to_string())
}

// Handle chat input and update requirements
async fn handle_chat(
    axum::extract::State(state): axum::extract::State<AppState>,
    Json(payload): Json<ChatRequest>,
) -> Json<ChatResponse> {
    let user_input = payload.message;

    // Call llama.cpp CLI (simplified; assumes model is in ../llama.cpp/models/)
    let output = Command::new("../llama.cpp/main.exe")
        .args(&[
            "-m", "../llama.cpp/models/llama-7b.gguf",
            "-p", &format!("You are an AI assistant helping me write a requirements document. User says: '{}'. Respond with a helpful reply and suggest updates to the requirements if needed.", user_input),
            "--temp", "0.7",
            "-n", "512",
        ])
        .output()
        .expect("Failed to run llama.cpp");

    let ai_response = String::from_utf8_lossy(&output.stdout).to_string();

    // Update requirements if AI suggests it (basic parsing for demo)
    let mut reqs = state.requirements.lock().await;
    if ai_response.contains("Update requirements:") {
        let new_req = ai_response
            .split("Update requirements:")
            .nth(1)
            .unwrap_or("")
            .trim();
        *reqs += &format!("\n- {}", new_req);
    }

    Json(ChatResponse {
        message: ai_response,
    })
}

// Serve current requirements
async fn get_requirements(axum::extract::State(state): axum::extract::State<AppState>) -> String {
    state.requirements.lock().await.clone()
}

#[derive(Deserialize)]
struct ChatRequest {
    message: String,
}

#[derive(Serialize)]
struct ChatResponse {
    message: String,
}
