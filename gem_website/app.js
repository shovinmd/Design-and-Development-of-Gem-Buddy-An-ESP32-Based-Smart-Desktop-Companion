/* ==========================================================================
   GEM Buddy Showcase Website - Interaction Script
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Mobile Menu Toggle
    const menuToggle = document.getElementById('menu-toggle');
    const mainNav = document.getElementById('main-nav');
    const navLinks = document.querySelectorAll('.nav-link, .nav-btn');

    if (menuToggle && mainNav) {
        menuToggle.addEventListener('click', () => {
            menuToggle.classList.toggle('open');
            mainNav.classList.toggle('open');
        });

        // Close menu when clicking navigation links
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                menuToggle.classList.remove('open');
                mainNav.classList.remove('open');
            });
        });
    }

    // 2. Interactive Device Simulator
    const faceImg = document.getElementById('device-face-img');
    const sleepOverlay = document.getElementById('sleep-overlay');
    const guardOverlay = document.getElementById('guard-overlay');
    const statusText = document.getElementById('simulator-status-text');
    const ldrFill = document.getElementById('sim-ldr-fill');
    const ldrVal = document.getElementById('sim-ldr-val');
    const ctrlButtons = document.querySelectorAll('.ctrl-btn');

    // Simulator states config
    const states = {
        happy: {
            img: 'assets/images/gem_happy.jpg',
            status: 'GEM is happy, connected to WiFi, and tracking ambient desk light.',
            ldr: 65,
            showSleep: false,
            showGuard: false
        },
        sleep: {
            img: 'assets/images/gem_happy.jpg',
            status: 'GEM is sleeping. Auto-dimmed display active. Standing by for touch waking.',
            ldr: 12,
            showSleep: true,
            showGuard: false
        },
        angry: {
            img: 'assets/images/gem_angry.jpg',
            status: 'Alert! Sensor fluctuation or sudden shadow registered in the log.',
            ldr: 30,
            showSleep: false,
            showGuard: false
        },
        sad: {
            img: 'assets/images/gem_sad.jpg',
            status: 'Low battery warning or device disconnected. Checking backup state.',
            ldr: 8,
            showSleep: false,
            showGuard: false
        },
        guard: {
            img: 'assets/images/gem_angry.jpg',
            status: 'Desk Guard Mode active. Webhooks primed to alert on touch or light changes.',
            ldr: 48,
            showSleep: false,
            showGuard: true
        }
    };

    ctrlButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const face = btn.getAttribute('data-face');
            const state = states[face];

            if (!state) return;

            // Update active button styling
            ctrlButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Apply updates to mock hardware device
            faceImg.src = state.img;
            statusText.textContent = state.status;
            
            // LDR Telemetry bar update
            ldrFill.style.width = `${state.ldr}%`;
            ldrVal.textContent = `${state.ldr}%`;

            // Sleep overlay display
            if (state.showSleep) {
                sleepOverlay.style.display = 'block';
                faceImg.style.opacity = '0.15';
            } else {
                sleepOverlay.style.display = 'none';
                faceImg.style.opacity = '0.95';
            }

            // Guard overlay display
            if (state.showGuard) {
                guardOverlay.style.display = 'block';
            } else {
                guardOverlay.style.display = 'none';
            }
        });
    });

    // 3. Tutorial Video Player Mockup Simulation
    const playOverlay = document.getElementById('video-play-overlay');
    const timelinePlayed = document.querySelector('.timeline-played');
    const timelineHandle = document.querySelector('.timeline-handle');
    const timeLabel = document.querySelector('.time-label');
    const playButtonAction = document.getElementById('play-button-action');

    let videoInterval = null;

    const startMockVideoTimeline = () => {
        if (videoInterval) clearInterval(videoInterval);
        
        let percentage = 40;
        let seconds = 134; // 2:14 out of 5:40 (340 seconds total)
        const totalSeconds = 340;

        videoInterval = setInterval(() => {
            seconds++;
            if (seconds >= totalSeconds) {
                seconds = 0;
            }
            percentage = (seconds / totalSeconds) * 100;
            
            // Update UI elements
            if (timelinePlayed) timelinePlayed.style.width = `${percentage}%`;
            if (timelineHandle) timelineHandle.style.left = `${percentage}%`;
            
            const curMin = Math.floor(seconds / 60);
            const curSec = Math.floor(seconds % 60).toString().padStart(2, '0');
            const totMin = Math.floor(totalSeconds / 60);
            const totSec = Math.floor(totalSeconds % 60).toString().padStart(2, '0');
            
            if (timeLabel) {
                timeLabel.textContent = `${curMin}:${curSec} / ${totMin}:${totSec}`;
            }
        }, 1000);
    };

    if (playOverlay) {
        // Support overlay click to trigger mock video playing
        playOverlay.addEventListener('click', () => {
            playOverlay.style.opacity = '0';
            setTimeout(() => {
                playOverlay.style.display = 'none';
            }, 350);

            // Change loader text to streaming status
            const loadingText = document.querySelector('.video-loading-text');
            if (loadingText) {
                loadingText.textContent = 'Streaming Setup Walkthrough... (YouTube Video Placeholder)';
            }
            
            const spinner = document.querySelector('.spinner');
            if (spinner) {
                spinner.style.borderTopColor = '#10b981'; // Green active playing state spinner
            }

            // Animate timeline
            startMockVideoTimeline();
        });
    }

    // 4. Prebook Notify Signup Form & Modal popup
    const bookingForm = document.getElementById('booking-form');
    const userEmail = document.getElementById('user-email');
    const submitBtn = document.getElementById('btn-submit-booking');
    const formFeedback = document.getElementById('form-feedback');
    const successModal = document.getElementById('success-modal');
    const modalClose = document.getElementById('modal-close-btn');
    const modalOk = document.getElementById('modal-ok-btn');

    if (bookingForm) {
        bookingForm.addEventListener('submit', (e) => {
            e.preventDefault();

            const emailValue = userEmail.value.trim();
            if (!emailValue) return;

            // Simple visual loader feedback
            submitBtn.textContent = 'Subscribing...';
            submitBtn.disabled = true;

            setTimeout(() => {
                // Restore button
                submitBtn.textContent = 'Notify Me';
                submitBtn.disabled = false;
                
                // Open visual popup modal
                if (successModal) {
                    successModal.style.display = 'flex';
                }
                
                // Reset input
                userEmail.value = '';
            }, 1000);
        });
    }

    // Modal dismiss logic
    const closeModal = () => {
        if (successModal) {
            successModal.style.display = 'none';
        }
    };

    if (modalClose) modalClose.addEventListener('click', closeModal);
    if (modalOk) modalOk.addEventListener('click', closeModal);
    
    // Dismiss on clicking outside content
    window.addEventListener('click', (e) => {
        if (e.target === successModal) {
            closeModal();
        }
    });

    // 5. Trackpad feature card spotlight effect (ambient background hover follow)
    const cards = document.querySelectorAll('.feature-card');
    cards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            card.style.setProperty('--x', `${x}px`);
            card.style.setProperty('--y', `${y}px`);
        });
    });

    // 6. Automatic mobile app showcase slideshow
    let currentSlide = 0;
    const slides = [
        document.getElementById('app-slide-0'),
        document.getElementById('app-slide-1'),
        document.getElementById('app-slide-2'),
        document.getElementById('app-slide-3')
    ];

    if (slides[0]) {
        setInterval(() => {
            if (slides[currentSlide]) {
                slides[currentSlide].classList.remove('active');
            }
            currentSlide = (currentSlide + 1) % slides.length;
            if (slides[currentSlide]) {
                slides[currentSlide].classList.add('active');
            }
        }, 3500);
    }
});
