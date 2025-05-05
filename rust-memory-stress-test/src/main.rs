use raylib::prelude::*;
use rand::prelude::*;
use std::time::{Duration, Instant};
use memory_stats::memory_stats;

struct Circle {
    x: f32,
    y: f32,
    radius: f32,
    speed: f32,
    color: Color,
}

fn get_memory_usage() -> f32 {
    // Use memory-stats crate to get actual memory usage
    if let Some(usage) = memory_stats() {
        // Convert from bytes to MB
        return usage.physical_mem as f32 / (1024.0 * 1024.0);
    }
    0.0
}

fn main() {
    let (screen_width, screen_height) = (800, 600);
    
    // Initialize raylib - using proper tuple destructuring
    let (mut rl_handle, thread) = raylib::init()
        .size(screen_width, screen_height)
        .title("Rust Raylib Performance Test")
        .build();
    
    // Set target FPS
    rl_handle.set_target_fps(60);
    
    // Memory stress test variables
    let mut stress_enabled = false;
    let mut stress_level = 1;
    let mut objects_created = 0;
    let objects_retained = 1000;
    let stress_objects_per_level = [100, 1000, 10000];
    let mut objects: Vec<Vec<u8>> = Vec::new();
    
    // Initialize circles
    let mut circles = Vec::new();
    let mut rng = rand::thread_rng();
    
    for _ in 0..20 {
        circles.push(Circle {
            x: rng.gen_range(0.0..800.0),
            y: rng.gen_range(300.0..500.0),
            radius: rng.gen_range(5.0..25.0),
            speed: rng.gen_range(50.0..250.0),
            color: Color::new(
                rng.gen_range(0..255),
                rng.gen_range(0..255),
                rng.gen_range(0..255),
                255,
            ),
        });
    }
    
    // Rotation angle
    let mut rotation = 0.0;
    
    // Performance measurement variables
    let mut frame_times = vec![0.0; 120];
    let mut frame_index = 0;
    let mut max_frame_time = 0.0;
    let mut last_max_reset_time = Instant::now();
    
    // Timing measurement
    let mut update_time = 0.0;
    let mut render_time = 0.0;
    let mut stress_time = 0.0;

    // Main game loop
    while !rl_handle.window_should_close() {
        let delta_time = rl_handle.get_frame_time();
        
        // Record frame time
        frame_times[frame_index] = delta_time;
        frame_index = (frame_index + 1) % frame_times.len();
        
        if delta_time > max_frame_time {
            max_frame_time = delta_time;
        }
        
        // Reset maximum frame time every 5 seconds
        if last_max_reset_time.elapsed() > Duration::from_secs(5) {
            last_max_reset_time = Instant::now();
            max_frame_time = 0.0;
        }
        
        // Update animations (with timing)
        let update_start = Instant::now();
        
        // Update rotation
        rotation += 90.0 * delta_time;
        
        // Update circle positions
        for circle in &mut circles {
            circle.x += circle.speed * delta_time;
            if circle.x > screen_width as f32 + circle.radius {
                circle.x = -circle.radius;
            }
        }
        update_time = update_start.elapsed().as_secs_f32();
        
        // Process key inputs
        if rl_handle.is_key_pressed(KeyboardKey::KEY_G) {
            stress_enabled = !stress_enabled;
        }
        
        if rl_handle.is_key_pressed(KeyboardKey::KEY_ONE) {
            stress_level = 1;
        }
        if rl_handle.is_key_pressed(KeyboardKey::KEY_TWO) {
            stress_level = 2;
        }
        if rl_handle.is_key_pressed(KeyboardKey::KEY_THREE) {
            stress_level = 3;
        }
        
        if rl_handle.is_key_pressed(KeyboardKey::KEY_R) {
            objects.clear();
            objects_created = 0;
        }
        
        // Memory stress test (with timing)
        let stress_start = Instant::now();
        if stress_enabled {
            let objects_per_frame = stress_objects_per_level[stress_level - 1];
            for _ in 0..objects_per_frame {
                objects.push(vec![0; 1000]);
                objects_created += 1;
            }
            
            // Limit the number of objects
            if objects.len() > objects_retained {
                objects.drain(0..(objects.len() - objects_retained));
            }
        }
        stress_time = stress_start.elapsed().as_secs_f32();
        
        // Drawing (with timing)
        let render_start = Instant::now();
        let mut d = rl_handle.begin_drawing(&thread);
        
        d.clear_background(Color::WHITE);
        
        // Draw circles
        for circle in &circles {
            d.draw_circle(
                circle.x as i32,
                circle.y as i32,
                circle.radius,
                circle.color,
            );
        }
        
        // Draw rotating rectangle
        let center_x = 400.0;
        let center_y = 300.0;
        d.draw_rectangle_pro(
            Rectangle::new(center_x, center_y, 100.0, 100.0),
            Vector2::new(50.0, 50.0),
            rotation,
            Color::RED,
        );
        
        // Display information
        let current_memory = get_memory_usage();
        d.draw_text(&format!("Memory Usage: {:.2} MB", current_memory), 20, 20, 20, Color::BLACK);
        d.draw_text(&format!("FPS: {}", d.get_fps()), 20, 50, 20, Color::BLACK);
        d.draw_text(&format!("Max Frame Time: {:.2} ms", max_frame_time * 1000.0), 20, 80, 20, Color::BLACK);
        
        // Display memory stress status
        let stress_text = if stress_enabled {
            format!("ON (Level {})", stress_level)
        } else {
            "OFF".to_string()
        };
        d.draw_text(&format!("Memory Stress: {}", stress_text), 20, 210, 20, 
                    if stress_enabled { Color::RED } else { Color::GREEN });
        d.draw_text(&format!("Objects Created: {}", objects_created), 20, 240, 20, Color::BLACK);
        d.draw_text(&format!("Objects Retained: {}", objects.len()), 20, 270, 20, Color::BLACK);
        
        // Display performance measurements
        d.draw_text(&format!("Update Time: {:.2} ms", update_time * 1000.0), 20, 500, 18, Color::DARKGRAY);
        d.draw_text(&format!("Render Time: {:.2} ms", render_time * 1000.0), 20, 530, 18, Color::DARKGRAY);
        d.draw_text(&format!("Stress Test Time: {:.2} ms", stress_time * 1000.0), 20, 560, 18, Color::DARKGRAY);
        
        // Instructions
        d.draw_text("Instructions:", 20, 340, 20, Color::DARKGRAY);
        d.draw_text("- G: Toggle memory stress test", 40, 370, 18, Color::DARKGRAY);
        d.draw_text("- 1/2/3: Select stress level (low/medium/high)", 40, 400, 18, Color::DARKGRAY);
        d.draw_text("- R: Reset metrics", 40, 430, 18, Color::DARKGRAY);
        d.draw_text("- ESC: Exit", 40, 460, 18, Color::DARKGRAY);
        
        // Don't need to explicitly end drawing with newer raylib bindings
        
        render_time = render_start.elapsed().as_secs_f32();
    }
}
