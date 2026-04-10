// Mobile Menu Toggle
const menuBtn = document.getElementById('menuBtn');
const navMenu = document.getElementById('navMenu');

menuBtn.addEventListener('click', () => {
    navMenu.classList.toggle('active');
});

// Hero Slider
const slides = document.querySelectorAll('.slide');
const indicators = document.querySelectorAll('.indicator');
let currentSlide = 0;

function showSlide(index) {
    slides.forEach(slide => slide.classList.remove('active'));
    indicators.forEach(indicator => indicator.classList.remove('active'));
    
    slides[index].classList.add('active');
    indicators[index].classList.add('active');
    currentSlide = index;
}

function nextSlide() {
    let next = currentSlide + 1;
    if (next >= slides.length) next = 0;
    showSlide(next);
}

// Auto slide every 5 seconds
setInterval(nextSlide, 5000);

// Click on indicators
indicators.forEach(indicator => {
    indicator.addEventListener('click', function() {
        showSlide(parseInt(this.dataset.slide));
    });
});

// Portfolio Tabs
const portfolioTabs = document.querySelectorAll('.portfolio-tab');
const finitionGrid = document.getElementById('finitionGrid');
const impressionGrid = document.getElementById('impressionGrid');

portfolioTabs.forEach(tab => {
    tab.addEventListener('click', () => {
        // Remove active class from all tabs
        portfolioTabs.forEach(t => t.classList.remove('active'));
        
        // Add active class to clicked tab
        tab.classList.add('active');
        
        // Show the selected grid
        if(tab.dataset.category === 'finition') {
            finitionGrid.style.display = 'grid';
            impressionGrid.style.display = 'none';
        } else {
            finitionGrid.style.display = 'none';
            impressionGrid.style.display = 'grid';
        }
    });
});

// Smooth Scrolling for Navigation
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            window.scrollTo({
                top: target.offsetTop - 70,
                behavior: 'smooth'
            });
            
            // Close mobile menu if open
            navMenu.classList.remove('active');
        }
    });
});

// Form Submission
const contactForm = document.getElementById('contactForm');

contactForm.addEventListener('submit', function(e) {
    e.preventDefault();
    
    // Get form values
    const name = document.getElementById('name').value;
    const email = document.getElementById('email').value;
    const service = document.getElementById('service').value;
    const message = document.getElementById('message').value;
    
    // In a real application, you would send this data to a server
    // Here we'll just show a confirmation message
    alert(`Merci ${name} ! Votre message a été envoyé avec succès. Nous vous contacterons bientôt à l'adresse ${email}.`);
    
    // Reset form
    contactForm.reset();
});

// Animation on scroll
const animateElements = document.querySelectorAll('.animate');

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = 1;
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, {
    threshold: 0.1
});

animateElements.forEach(element => {
    element.style.opacity = 0;
    element.style.transform = 'translateY(20px)';
    element.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(element);
});