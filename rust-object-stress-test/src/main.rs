use raylib::prelude::*;
use rand::prelude::*;
use std::time::{Duration, Instant};
use memory_stats::memory_stats;

// 2D objects
struct Circle {
    x: f32,
    y: f32,
    radius: f32,
    speed: f32,
    color: Color,
}

struct Rectangle2D {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    speed: f32,
    color: Color,
}

// 3D objects
struct Cube {
    position: Vector3,
    size: Vector3,
    rotation: f32,
    color: Color,
}

// Shape type enum
enum ShapeType {
    Circle,
    Rectangle,
    Mixed,
}

// Render mode enum
enum RenderMode {
    Mode2D,
    Mode3D,
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
    
    // Initialize raylib
    let (mut rl_handle, thread) = raylib::init()
        .size(screen_width, screen_height)
        .title("Rust Raylib Object Rendering Test")
        .build();
    
    // Set target FPS
    rl_handle.set_target_fps(60);
    
    // Initialize random number generator
    let mut rng = rand::thread_rng();
    
    // Rendering parameters
    let mut render_mode = RenderMode::Mode2D;
    let mut shape_type = ShapeType::Circle;
    let mut base_object_count = 100;
    let mut power_multiplier = 1;
    
    // Object collections
    let mut circles: Vec<Circle> = Vec::new();
    let mut rectangles: Vec<Rectangle2D> = Vec::new();
    let mut cubes: Vec<Cube> = Vec::new();
    
    // Camera for 3D mode
    let mut camera = Camera::perspective(
        Vector3::new(0.0, 10.0, 20.0),  // position
        Vector3::new(0.0, 0.0, 0.0),    // target
        Vector3::new(0.0, 1.0, 0.0),    // up
        45.0                            // fovy
    );
    
    // Performance measurement variables
    let mut frame_times = vec![0.0; 120];
    let mut frame_index = 0;
    let mut max_frame_time = 0.0;
    let mut last_max_reset_time = Instant::now();
    let mut last_processing_time = 0.0;
    
    // Initialize objects
    initialize_objects(
        &mut circles,
        &mut rectangles,
        &mut cubes,
        &render_mode,
        &shape_type,
        base_object_count,
        power_multiplier,
        &mut rng
    );
    
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
        
        // Start processing time measurement
        let processing_start = Instant::now();
        
        // Update animations
        update_animations(&mut circles, &mut rectangles, &mut cubes, delta_time);
        
        // Handle input
        // Toggle between 2D and 3D with TAB key
        if rl_handle.is_key_pressed(KeyboardKey::KEY_TAB) {
            render_mode = match render_mode {
                RenderMode::Mode2D => RenderMode::Mode3D,
                RenderMode::Mode3D => RenderMode::Mode2D,
            };
            println!("Switched to {} rendering mode", 
                     match render_mode {
                         RenderMode::Mode2D => "2D",
                         RenderMode::Mode3D => "3D",
                     });
            
            initialize_objects(
                &mut circles,
                &mut rectangles,
                &mut cubes,
                &render_mode,
                &shape_type,
                base_object_count,
                power_multiplier,
                &mut rng
            );
        }
        
        // Toggle shape type with S key
        if rl_handle.is_key_pressed(KeyboardKey::KEY_S) {
            shape_type = match shape_type {
                ShapeType::Circle => ShapeType::Rectangle,
                ShapeType::Rectangle => ShapeType::Mixed,
                ShapeType::Mixed => ShapeType::Circle,
            };
            println!("Shape type set to: {}", 
                     match shape_type {
                         ShapeType::Circle => "circle",
                         ShapeType::Rectangle => "rectangle",
                         ShapeType::Mixed => "mixed",
                     });
            
            initialize_objects(
                &mut circles,
                &mut rectangles,
                &mut cubes,
                &render_mode,
                &shape_type,
                base_object_count,
                power_multiplier,
                &mut rng
            );
        }
        
        // Adjust base object count with UP/DOWN keys
        if rl_handle.is_key_pressed(KeyboardKey::KEY_UP) {
            base_object_count = (base_object_count + 10).min(1000);
            println!("Base value: {} (Total: {})", 
                     base_object_count, 
                     get_actual_object_count(base_object_count, power_multiplier));
            
            initialize_objects(
                &mut circles,
                &mut rectangles,
                &mut cubes,
                &render_mode,
                &shape_type,
                base_object_count,
                power_multiplier,
                &mut rng
            );
        }
        
        if rl_handle.is_key_pressed(KeyboardKey::KEY_DOWN) {
            base_object_count = (base_object_count - 10).max(10);
            println!("Base value: {} (Total: {})", 
                     base_object_count, 
                     get_actual_object_count(base_object_count, power_multiplier));
            
            initialize_objects(
                &mut circles,
                &mut rectangles,
                &mut cubes,
                &render_mode,
                &shape_type,
                base_object_count,
                power_multiplier,
                &mut rng
            );
        }
        
        // Adjust power multiplier with LEFT/RIGHT keys
        if rl_handle.is_key_pressed(KeyboardKey::KEY_RIGHT) {
            power_multiplier = (power_multiplier + 1).min(5);
            println!("Power multiplier: 10^{} (Total: {})", 
                     power_multiplier - 1, 
                     get_actual_object_count(base_object_count, power_multiplier));
            
            initialize_objects(
                &mut circles,
                &mut rectangles,
                &mut cubes,
                &render_mode,
                &shape_type,
                base_object_count,
                power_multiplier,
                &mut rng
            );
        }
        
        if rl_handle.is_key_pressed(KeyboardKey::KEY_LEFT) {
            power_multiplier = (power_multiplier - 1).max(1);
            println!("Power multiplier: 10^{} (Total: {})", 
                     power_multiplier - 1, 
                     get_actual_object_count(base_object_count, power_multiplier));
            
            initialize_objects(
                &mut circles,
                &mut rectangles,
                &mut cubes,
                &render_mode,
                &shape_type,
                base_object_count,
                power_multiplier,
                &mut rng
            );
        }
        
        // End processing time measurement
        last_processing_time = processing_start.elapsed().as_secs_f32() * 1000.0;
        
        // Drawing
        let mut d = rl_handle.begin_drawing(&thread);
        
        d.clear_background(Color::WHITE);
        
        // Draw based on current render mode
        match render_mode {
            RenderMode::Mode2D => {
                // Draw circles
                for circle in &circles {
                    d.draw_circle(
                        circle.x as i32,
                        circle.y as i32,
                        circle.radius,
                        circle.color,
                    );
                }
                
                // Draw rectangles
                for rect in &rectangles {
                    d.draw_rectangle(
                        rect.x as i32,
                        rect.y as i32,
                        rect.width as i32,
                        rect.height as i32,
                        rect.color,
                    );
                }
            },
            RenderMode::Mode3D => {
                // 3D rendering
                let mut camera_3d = d.begin_mode3D(camera);
                
                // Draw grid
                camera_3d.draw_grid(20, 1.0);
                
                // Draw cubes
                for cube in &cubes {
                    camera_3d.draw_cube_v(
                        cube.position,
                        cube.size,
                        cube.color,
                    );
                    camera_3d.draw_cube_wires_v(
                        cube.position,
                        cube.size,
                        Color::BLACK,
                    );
                }
            }
        }
        
        // Display information
        let current_memory = get_memory_usage();
        let actual_count = get_actual_object_count(base_object_count, power_multiplier);
        
        // Helper function to draw text with background
        fn draw_text_with_bg(d: &mut RaylibDrawHandle, text: &str, x: i32, y: i32, font_size: i32, color: Color) {
            let text_width = d.measure_text(text, font_size);
            d.draw_rectangle(
                x - 5, 
                y - 5, 
                text_width + 10, 
                font_size + 10, 
                Color::new(255, 255, 255, 220)
            );
            d.draw_text(text, x, y, font_size, color);
        }
        
        // Draw performance information
        let fps = d.get_fps();
        draw_text_with_bg(&mut d, &format!("FPS: {}", fps), 20, 20, 20, Color::BLACK);
        draw_text_with_bg(&mut d, &format!("Memory Usage: {:.2} MB", current_memory), 20, 50, 20, Color::BLACK);
        draw_text_with_bg(&mut d, &format!("Max Frame Time: {:.2} ms", max_frame_time * 1000.0), 20, 80, 20, Color::BLACK);
        draw_text_with_bg(&mut d, &format!("Last Processing Time: {:.2} ms", last_processing_time), 20, 110, 20, Color::DARKBLUE);
        
        // Draw rendering information
        draw_text_with_bg(&mut d, &format!("Mode: {}", 
                                          match render_mode {
                                              RenderMode::Mode2D => "2d",
                                              RenderMode::Mode3D => "3d",
                                          }), 20, 150, 20, Color::DARKGREEN);
        
        draw_text_with_bg(&mut d, &format!("Shape Type: {}", 
                                          match shape_type {
                                              ShapeType::Circle => "circle",
                                              ShapeType::Rectangle => "rectangle",
                                              ShapeType::Mixed => "mixed",
                                          }), 20, 180, 20, Color::DARKGREEN);
        
        draw_text_with_bg(&mut d, &format!("Base Value: {}", base_object_count), 20, 210, 20, Color::DARKGREEN);
        draw_text_with_bg(&mut d, &format!("Power Multiplier: 10^{}", power_multiplier - 1), 20, 240, 20, Color::DARKGREEN);
        draw_text_with_bg(&mut d, &format!("Total Objects: {}", actual_count), 20, 270, 20, Color::DARKGREEN);
        
        // Display triangle and vertex count in 3D mode
        if let RenderMode::Mode3D = render_mode {
            let triangle_count = actual_count * 12; // Each cube has 12 triangles
            let vertex_count = actual_count * 36;   // Each cube has 36 vertices
            
            draw_text_with_bg(&mut d, &format!("Triangle Count: {}", triangle_count), 20, 300, 20, Color::DARKGREEN);
            draw_text_with_bg(&mut d, &format!("Vertex Count: {}", vertex_count), 20, 330, 20, Color::DARKGREEN);
        }
        
        // Help instructions
        draw_text_with_bg(&mut d, "Controls:", 20, 380, 20, Color::DARKGRAY);
        draw_text_with_bg(&mut d, "- UP/DOWN: Adjust base value by 10", 40, 410, 18, Color::DARKGRAY);
        draw_text_with_bg(&mut d, "- LEFT/RIGHT: Adjust power multiplier (10^n)", 40, 440, 18, Color::DARKGRAY);
        draw_text_with_bg(&mut d, "- S: Cycle shape types (Circle → Rectangle → Mixed)", 40, 470, 18, Color::DARKGRAY);
        draw_text_with_bg(&mut d, "- TAB: Toggle between 2D and 3D mode", 40, 500, 18, Color::DARKGRAY);
        draw_text_with_bg(&mut d, "- ESC: Exit", 40, 530, 18, Color::DARKGRAY);
        
        draw_text_with_bg(
            &mut d, 
            &format!("Formula: {} × 10^{} = {} objects", 
                    base_object_count, 
                    power_multiplier - 1, 
                    actual_count), 
            40, 560, 18, Color::DARKBLUE
        );
    }
}

// Calculate actual object count based on base count and multiplier
fn get_actual_object_count(base: i32, multiplier: i32) -> i32 {
    base * 10i32.pow((multiplier - 1) as u32)
}

// Initialize objects based on current mode and settings
fn initialize_objects(
    circles: &mut Vec<Circle>,
    rectangles: &mut Vec<Rectangle2D>,
    cubes: &mut Vec<Cube>,
    render_mode: &RenderMode,
    shape_type: &ShapeType,
    base_count: i32,
    power_multiplier: i32,
    rng: &mut ThreadRng
) {
    let actual_count = get_actual_object_count(base_count, power_multiplier);
    
    // Clear existing objects
    circles.clear();
    rectangles.clear();
    cubes.clear();
    
    match render_mode {
        RenderMode::Mode2D => {
            println!("Creating {} 2D objects", actual_count);
            
            match shape_type {
                ShapeType::Circle => {
                    // Create only circles
                    for _ in 0..actual_count.min(10000) {
                        circles.push(Circle {
                            x: rng.gen_range(0.0..800.0),
                            y: rng.gen_range(100.0..500.0),
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
                },
                ShapeType::Rectangle => {
                    // Create only rectangles
                    for _ in 0..actual_count.min(10000) {
                        rectangles.push(Rectangle2D {
                            x: rng.gen_range(0.0..800.0),
                            y: rng.gen_range(100.0..500.0),
                            width: rng.gen_range(10.0..50.0),
                            height: rng.gen_range(10.0..50.0),
                            speed: rng.gen_range(30.0..180.0),
                            color: Color::new(
                                rng.gen_range(0..255),
                                rng.gen_range(0..255),
                                rng.gen_range(0..255),
                                255,
                            ),
                        });
                    }
                },
                ShapeType::Mixed => {
                    // Create both circles and rectangles
                    let half_count = actual_count / 2;
                    
                    for _ in 0..half_count.min(5000) {
                        circles.push(Circle {
                            x: rng.gen_range(0.0..800.0),
                            y: rng.gen_range(100.0..500.0),
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
                    
                    for _ in 0..half_count.min(5000) {
                        rectangles.push(Rectangle2D {
                            x: rng.gen_range(0.0..800.0),
                            y: rng.gen_range(100.0..500.0),
                            width: rng.gen_range(10.0..50.0),
                            height: rng.gen_range(10.0..50.0),
                            speed: rng.gen_range(30.0..180.0),
                            color: Color::new(
                                rng.gen_range(0..255),
                                rng.gen_range(0..255),
                                rng.gen_range(0..255),
                                255,
                            ),
                        });
                    }
                }
            }
        },
        RenderMode::Mode3D => {
            println!("Creating {} 3D objects", actual_count);
            
            // Create cubes
            for _ in 0..actual_count.min(5000) {
                cubes.push(Cube {
                    position: Vector3::new(
                        rng.gen_range(-10.0..10.0),
                        rng.gen_range(-5.0..5.0),
                        rng.gen_range(-10.0..10.0),
                    ),
                    size: Vector3::new(
                        rng.gen_range(0.5..2.5),
                        rng.gen_range(0.5..2.5),
                        rng.gen_range(0.5..2.5),
                    ),
                    rotation: rng.gen_range(0.0..360.0),
                    color: Color::new(
                        rng.gen_range(0..255),
                        rng.gen_range(0..255),
                        rng.gen_range(0..255),
                        255,
                    ),
                });
            }
        }
    }
}

// Update animations for all objects
fn update_animations(
    circles: &mut Vec<Circle>,
    rectangles: &mut Vec<Rectangle2D>,
    cubes: &mut Vec<Cube>,
    delta_time: f32
) {
    // Update circle positions
    for circle in circles.iter_mut() {
        circle.x += circle.speed * delta_time;
        if circle.x > 800.0 + circle.radius {
            circle.x = -circle.radius;
        }
    }
    
    // Update rectangle positions
    for rect in rectangles.iter_mut() {
        rect.x += rect.speed * delta_time;
        if rect.x > 800.0 + rect.width {
            rect.x = -rect.width;
        }
    }
    
    // Update cube rotations
    for cube in cubes.iter_mut() {
        cube.rotation += 45.0 * delta_time; // 45 degrees per second
        if cube.rotation > 360.0 {
            cube.rotation -= 360.0;
        }
    }
}
