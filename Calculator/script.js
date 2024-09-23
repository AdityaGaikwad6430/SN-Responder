// Insert numbers and operators into the display
function insert(value) {
    document.getElementById("result").value += value;
}

// Clear the display
function clearResult() {
    document.getElementById("result").value = "";
}

// Delete the last character
function deleteLast() {
    let result = document.getElementById("result").value;
    document.getElementById("result").value = result.slice(0, -1);
}

// Calculate the result
function calculate() {
    try {
        let result = eval(document.getElementById("result").value);
        document.getElementById("result").value = result;
    } catch (error) {
        alert("Invalid Expression");
    }
}