document.addEventListener("DOMContentLoaded", function () {
  const toggle = document.querySelector(".menu-toggle");
  const menu = document.querySelector(".site-menu");

  if (toggle && menu) {
    toggle.addEventListener("click", function () {
      menu.classList.toggle("active");
    });
  }
});