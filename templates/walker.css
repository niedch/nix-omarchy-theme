@define-color selected-text {{ accent }};
@define-color text {{ foreground }};
@define-color base {{ background }};
@define-color border {{ selection_background }};
@define-color select {{ color11 }};
@define-color purple {{ color5 }};
@define-color surface {{ background }};

window * {
    all: unset;
    color: @text;
    background: none;
    border: none;
    margin: 0;
    padding: 0;
    line-height: 1em;
}

window .normal-icons,
window .large-icons,
window .item-image,
window .symbols {
    -gtk-icon-size: 18px;
    min-width: 0;
    min-height: 0;
    padding: 0;
    margin: 0;
    display: none;
}

window .box-wrapper {
    background: alpha(@base, 1);
    border: 2px solid alpha(@border, 0.9);
    border-radius: 6px;
    padding: 4px;
    margin: 0;
    box-shadow: 0 2px 12px alpha(black, 0.85);
    backdrop-filter: blur(1px);
}

window .search-container {
    border-radius: 3px;
    padding: 4px 6px;
    margin: 0;
    background: alpha(@border, .5);
    box-shadow: inset 0 0 6px alpha(@border, 0);
    backdrop-filter: blur(1px);
}

window .input {
    background: transparent;
    color: @text;
}

child:selected {
  background-color: alpha(@base, 0);
  border-radius: 3px;
}

child:selected .item-box {
background: alpha(@border, .5);
backdrop-filter: blur(1px);
border-radius: 3px;
}

child:selected .item-title,
child:selected .item-text {
    color: @selected-text;
}

.item-box {
    padding: 2px 12px;
    spacing: 8px;
    vertical-align: center;
}

.item-text {
    vertical-align: center;
    margin: 0;
    padding: 0;
}

.item-title {
    font-weight: bold;
    color: @text;
}

.item-subtitle {
    font-size: 10px;
    opacity: 0.7;
}

.item-icon {
    margin-right: 4px;
    vertical-align: center;
}

.elephant-hint,
.keybind-bind,
.keybind-label {
    border-radius: 8px;
    background-color: #b2fff3;
    color: @base;
    font-weight: bold;
    font-size: 12px;
    padding: 2px 4px;
    margin: 0 0 0 0;
    line-height: 1em;
}
