import { LightningElement, api, track } from 'lwc';

export default class SearchableCombobox extends LightningElement {
    @api label;
    @api placeholder = '';
    @api fieldLevelHelp;
    @api disabled = false;
    @api required = false;

    _options = [];
    _value = '';

    @track inputValue = '';
    @track query = '';
    @track isOpen = false;
    @track activeIndex = -1;

    @api
    get options() {
        return this._options;
    }
    set options(value) {
        this._options = Array.isArray(value) ? value : [];
        this.syncInputFromValue();
    }

    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v == null ? '' : String(v);
        this.syncInputFromValue();
    }

    syncInputFromValue() {
        const match = this._options.find((o) => o.value === this._value);
        const newLabel = match ? match.label : '';
        if (!this.isOpen) {
            this.inputValue = newLabel;
            this.query = '';
        }
    }

    get visibleOptions() {
        const q = (this.query || '').toLowerCase();
        const filtered = q
            ? this._options.filter((o) => (o.label || '').toLowerCase().includes(q))
            : this._options.slice();
        return filtered.map((o, idx) => ({
            value: o.value,
            label: o.label,
            ariaSelected: o.value === this._value ? 'true' : 'false',
            itemClass: this.optionClass(o.value === this._value, idx === this.activeIndex)
        }));
    }

    get hasMatches() {
        return this.visibleOptions.length > 0;
    }

    get comboboxContainerClass() {
        return 'slds-combobox_container';
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click${
            this.isOpen ? ' slds-is-open' : ''
        }`;
    }

    optionClass(isSelected, isActive) {
        const base = 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small';
        const focusClass = isActive ? ' slds-has-focus' : '';
        const selectedClass = isSelected ? ' slds-is-selected' : '';
        return base + focusClass + selectedClass;
    }

    handleFocus() {
        if (this.disabled) return;
        this.openDropdown();
    }

    openDropdown() {
        this.isOpen = true;
        // When opening, clear the input so the user sees all options (and
        // can start typing to filter). The current selection still shows
        // as highlighted in the list.
        this.query = '';
        this.inputValue = '';
        this.activeIndex = -1;
    }

    closeDropdown() {
        this.isOpen = false;
        this.activeIndex = -1;
        this.syncInputFromValue();
    }

    handleInput(event) {
        this.query = event.target.value;
        this.inputValue = event.target.value;
        this.isOpen = true;
        this.activeIndex = -1;
    }

    handleKeydown(event) {
        const visible = this.visibleOptions;
        switch (event.key) {
            case 'ArrowDown':
                event.preventDefault();
                if (!this.isOpen) {
                    this.openDropdown();
                    return;
                }
                this.activeIndex = Math.min(this.activeIndex + 1, visible.length - 1);
                break;
            case 'ArrowUp':
                event.preventDefault();
                if (this.isOpen) {
                    this.activeIndex = Math.max(this.activeIndex - 1, 0);
                }
                break;
            case 'Enter':
                if (this.isOpen && this.activeIndex >= 0 && this.activeIndex < visible.length) {
                    event.preventDefault();
                    this.commitSelection(visible[this.activeIndex].value);
                }
                break;
            case 'Escape':
                if (this.isOpen) {
                    event.preventDefault();
                    this.closeDropdown();
                }
                break;
            default:
                break;
        }
    }

    // Use mousedown (not click) so the option is committed before the input's
    // blur event fires and collapses the dropdown.
    handleOptionMouseDown(event) {
        event.preventDefault();
        const value = event.currentTarget.dataset.value;
        this.commitSelection(value);
    }

    handleBlur() {
        // Defer to allow option mousedown to be processed first.
        setTimeout(() => {
            this.closeDropdown();
        }, 0);
    }

    commitSelection(value) {
        this._value = value;
        this.syncInputFromValue();
        this.isOpen = false;
        this.activeIndex = -1;
        this.dispatchEvent(
            new CustomEvent('change', {
                detail: { value }
            })
        );
    }
}
