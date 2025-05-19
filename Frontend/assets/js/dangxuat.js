// Khi click vào liên kết "Đăng xuất"
document.getElementById("logout-link").addEventListener("click", function(e) {
  e.preventDefault(); // chặn nhảy tới #logoutBox
  document.getElementById("logoutBox").style.display = "flex"; // hiện box
});

// Đóng box khi click "Không"
function closeLogoutBox() {
  document.getElementById("logoutBox").style.display = "none";
}

// Xử lý khi xác nhận đăng xuất
function logout() {
//   alert("Đăng xuất thành công!"); // hoặc window.location.href = '/logout'
  window.location.href = "dangnhap.html"; //chuyển về trang đăng nhập
}

