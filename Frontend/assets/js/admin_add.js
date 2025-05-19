//Mở form thêm mới nhân viênviên
function openAddForm() {
  document.getElementById('addEmployeeBox').style.display = 'flex';
}

//Đóng form thêm mới nhân viên
function closeAddForm() {
  document.getElementById('addEmployeeBox').style.display = 'none';
}

//Mở form chỉnh sửa nhân viên
function openEditForm() {
  document.getElementById('editEmployeeBox').style.display = 'flex';
}

//Đóng form chỉnh sửa nhân viên
function closeEditForm() {
  document.getElementById('editEmployeeBox').style.display = 'none';
}


//Mở form chỉnh sửa khách hàng
function openEditFormCus() {
  document.getElementById('editCustomerBox').style.display = 'flex';
}

//Đóng form chỉnh sửa khách hàng
function closeEditFormCus() {
  document.getElementById('editCustomerBox').style.display = 'none';
}

//Mở form chi tiết thông tin khách hàng
document.querySelectorAll('.cus-name').forEach(item => {
    item.addEventListener('click', function () {
        const name = this.textContent;
        const status = this.closest('tr').children[1].textContent;

        // Hiện box
        document.getElementById('detailCusBox').style.display = 'flex';
    });
});

//Đóng form chi tiết thông tin khách hàng
function closeDetailCus() {
  document.getElementById('detailCusBox').style.display = 'none';
}

//Mở form chỉnh sửa hợp đồng của nlhd
function openEditFormContracs() {
  document.getElementById('editContracsBox').style.display = 'flex';
}

//Đóng form chỉnh sửa hợp đồng của nlhd
function closeEditFormContracs() {
  document.getElementById('editContracsBox').style.display = 'none';
}

//Mở form thêm mới hợp đồng
function openAddContracsForm() {
  document.getElementById('addContracsForm').style.display = 'flex';
}

//Đóng form thêm mới hợp đồng
function closeAddContracsForm() {
  document.getElementById('addContracsForm').style.display = 'none';
}

//Mở form chi tiết hợp đồng của kế toán
function openFormContracs() {
  document.getElementById('detailConBox').style.display = 'flex';
}

//Đóng form chi tiết hợp đồng của kế toán
function closeFormContracs() {
  document.getElementById('detailConBox').style.display = 'none';
}

//Mở form chi tiết thông tin khách hàng của kế toán
document.querySelectorAll('.cus-name').forEach(item => {
    item.addEventListener('click', function () {
        const name = this.textContent;
        const status = this.closest('tr').children[1].textContent;

        // Hiện box
        document.getElementById('detailCustomerBox').style.display = 'flex';
    });
});

//Đóng form chi tiết thông tin khách hàng của kế toán
function closeDetailCustomer() {
  document.getElementById('detailCustomerBox').style.display = 'none';
}

//Mở form chi tiết hợp đồng của người giám sát
function openFormCon() {
  document.getElementById('detailContracsBox').style.display = 'flex';
}

//Đóng form chi tiết hợp đồng của người giám sát
function closeFormCon() {
  document.getElementById('detailContracsBox').style.display = 'none';
}

//Mở form thông tin khách hàng của người giám sát
document.querySelectorAll('.cus-name').forEach(item => {
    item.addEventListener('click', function () {
        const name = this.textContent;
        const status = this.closest('tr').children[1].textContent;

        // Hiện box
        document.getElementById('detailCusBox').style.display = 'flex';
    });
});

//Đóng form thông tin khách hàng của người giám sát
function closeDetailCus() {
  document.getElementById('detailCusBox').style.display = 'none';
}
