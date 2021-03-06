// toggle visibility
function do_confirm( string, url ) {
  var answer = confirm(string);
  if (answer) {
    window.location = url;
  } else { 
    return false;
  }
  return true;
}

function enableFilterButton() {
    getByID("filter-button").style.display = "inline";
}

function toggleFilter() {
    var filterActive = getByID("filter-active");
    if (filterActive.style.display == "none") {
        filterActive.style.display = "block";
        getByID("filter-select").style.display = "none";
    } else {
        filterActive.style.display = "none";
        getByID("filter-select").style.display = "block";
    }
}

function setFilterCol(choice) {
    getByID('filter-select').className = "filter-" + choice;
    var mode_obj = getByID('filter-mode');
    if (!mode_obj) { return; }
    if (choice == 'none')
        mode_obj.selectedIndex = 0;
    else {
        mode_obj.selectedIndex = 1;
        var fld = getByID('filter-col');
        if (choice == 'status')
            fld.selectedIndex = 0;
        else if (choice == 'category_id')
            fld.selectedIndex = 1;
        else if (choice == 'author_id')
            fld.selectedIndex = 2;
        col_span = getByID("filter-text-col");
        if (fld.selectedIndex > -1 && col_span)
            col_span.innerHTML = '<strong>' +
                fld.options[fld.selectedIndex].text + '</strong>';
    }
}

var tableSelect;
function init()
{
	// setup
	tableSelect = new TC.TableSelect( "selector" );
	tableSelect.rowSelect = true;
	//setFilterCol('none');
}

TC.attachLoadEvent( init );

