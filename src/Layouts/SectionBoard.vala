/*
* Copyright © 2023 Alain M. (https://github.com/alainm23/planify)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Alain M. <alainmh23@gmail.com>
*/

public class Layouts.SectionBoard : Gtk.FlowBoxChild {
    public Objects.Section section { get; construct; }

    private Gtk.Grid widget_color;
    private Gtk.Label name_label;
    private Gtk.Label count_label;
    private Gtk.Label description_label;
    private Gtk.Revealer description_revealer;
    private Gtk.ListBox listbox;
    private Adw.Bin listbox_target;
    private Widgets.LoadingButton add_button;
    private Gtk.Box content_box;

    public bool is_inbox_section {
        get {
            return section.id == "";
        }
    }

    public bool is_loading {
		set {
			add_button.is_loading = value;
		}
	}

    public int section_count {
        get {
            return items_map.size;
        }
    }

    public Gee.HashMap <string, Layouts.ItemBoard> items_map = new Gee.HashMap <string, Layouts.ItemBoard> ();
    private Gee.HashMap<ulong, weak GLib.Object> signals_map = new Gee.HashMap<ulong, weak GLib.Object> ();

    public SectionBoard (Objects.Section section) {
        Object (
            section: section,
            focusable: false,
            width_request: 350,
            vexpand: true
        );
    }

    public SectionBoard.for_project (Objects.Project project) {
        var section = new Objects.Section ();
        section.id = "";
        section.project_id = project.id;
        section.name = _("(No Section)");

        Object (
            section: section,
            focusable: false,
            width_request: 350,
            vexpand: true
        );
    }

    ~SectionBoard () {
        print ("Destroying Layouts.SectionBoard\n");
    }

    construct {
        add_css_class ("row");

        widget_color = new Gtk.Grid () {
            valign = Gtk.Align.CENTER,
            height_request = 16,
            width_request = 16,
            margin_end = 6,
            margin_bottom = 2,
            css_classes = { "circle-color" }
        };

        name_label = new Gtk.Label (section.name) {
			halign = START,
			css_classes = { "font-bold" },
			margin_start = 6
		};

        count_label = new Gtk.Label (null) {
			margin_start = 9,
			halign = Gtk.Align.CENTER,
			css_classes = { "dim-label", "caption" }
		};

        var menu_button = new Gtk.MenuButton () {
            icon_name = "view-more-symbolic",
            popover = build_context_menu (),
            css_classes = { "flat" }
        };

        add_button = new Widgets.LoadingButton.with_icon ("plus-large-symbolic", 16) {
            css_classes = { "flat" },
            hexpand = true,
            halign = END
        };
        
        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_start = 6
        };

        header_box.append (widget_color);
        header_box.append (name_label);
        header_box.append (count_label);
        header_box.append (add_button);
        header_box.append (menu_button);

        description_label = new Gtk.Label (section.description.strip ()) {
            wrap = true,
            selectable = true,
            halign = START,
            css_classes = { "dim-label" },
            margin_start = 6,
            margin_top = 6,
            margin_bottom = 6
        };

        description_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
            child = description_label
        };

        listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE,
            css_classes = { "listbox-background", "drop-target-list" }
        };

        listbox_target = new Adw.Bin () {
            vexpand = true,
            margin_end = 6,
            margin_bottom = 12,
            child = listbox
        };

        var items_scrolled = new Widgets.ScrolledWindow (listbox_target);

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            vexpand = true,
            css_classes = { "transition", "drop-target-list" }
        };

        content_box.append (header_box);
        content_box.append (description_revealer);
        content_box.append (items_scrolled);

        child = content_box;
        update_request ();
        add_items ();
        build_drag_and_drop ();
        update_count_label (section_count);

        listbox.set_filter_func ((row) => {
			var item = ((Layouts.ItemBoard) row).item;
			bool return_value = true;

			if (section.project.filters.size <= 0) {
				return true;
			}

			return_value = false;
			foreach (Objects.Filters.FilterItem filter in section.project.filters.values) {
				if (filter.filter_type == FilterItemType.PRIORITY) {
					return_value = return_value || item.priority == int.parse (filter.value);
				} else if (filter.filter_type == FilterItemType.LABEL) {
					return_value = return_value || item.has_label (filter.value);
				} else if (filter.filter_type == FilterItemType.DUE_DATE) {
					if (filter.value == "1") {
						return_value = return_value || (item.has_due && Utils.Datetime.is_today (item.due.datetime));
					} else if (filter.value == "2") {
						return_value = return_value || (item.has_due && Utils.Datetime.is_this_week (item.due.datetime));
					} else if (filter.value == "3") {
						return_value = return_value || (item.has_due && Utils.Datetime.is_next_x_week (item.due.datetime, 7));
					} else if (filter.value == "4") {
						return_value = return_value || (item.has_due && Utils.Datetime.is_this_month (item.due.datetime));
					} else if (filter.value == "5") {
						return_value = return_value || (item.has_due && Utils.Datetime.is_next_x_week (item.due.datetime, 30));
					} else if (filter.value == "6") {
						return_value = return_value || !item.has_due;
					}
				}
			}

			return return_value;
		});

        signals_map[listbox.row_selected.connect ((row) => {
            var item = ((Layouts.ItemBoard) row).item;
        })] = listbox;

        signals_map[section.updated.connect (() => {
            update_request ();
        })] = section;

        if (is_inbox_section) {
            signals_map[section.project.item_added.connect ((item) => {
                add_item (item);
            })] = section.project;
        } else {
            signals_map[section.item_added.connect ((item) => {
                add_item (item);
            })] = section;
        }
        
        signals_map[Services.EventBus.get_default ().checked_toggled.connect ((item, old_checked) => {
            if (item.project_id == section.project_id && item.section_id == section.id &&
                !item.has_parent) {
                if (!old_checked) {
                    if (items_map.has_key (item.id)) {
                        items_map [item.id].hide_destroy ();
                        items_map.unset (item.id);
                    }
                } else {
                    if (!items_map.has_key (item.id)) {
                        items_map [item.id] = new Layouts.ItemBoard (item);
                        listbox.append (items_map [item.id]);
                    }
                }
            }
        })] = Services.EventBus.get_default ();

        signals_map[Services.Store.instance ().item_updated.connect ((item, update_id) => {
            if (!items_map.has_key (item.id)) {
                return;
            }

            if (items_map [item.id].update_id != update_id) {
                items_map [item.id].update_request ();
                update_sort ();
            }

            listbox.invalidate_filter ();
        })] = Services.Store.instance ();

        signals_map[Services.Store.instance ().item_pin_change.connect ((item) => {
			// vala-lint=no-space
			if (!item.pinned && item.project_id == section.project_id &&
				item.section_id == section.id && !item.has_parent &&
				!items_map.has_key (item.id)) {
				add_item (item);
			}

			if (item.pinned && items_map.has_key (item.id)) {
				items_map [item.id].hide_destroy ();
				items_map.unset (item.id);
			}
		})] = Services.Store.instance ();

        signals_map[Services.Store.instance ().item_deleted.connect ((item) => {
            if (items_map.has_key (item.id)) {
                items_map [item.id].hide_destroy ();
                items_map.unset (item.id);

                update_count_label (section_count);
            }
        })] = Services.Store.instance ();

        signals_map[Services.EventBus.get_default ().item_moved.connect ((item, old_project_id, old_section_id, old_parent_id) => {
            if (old_project_id == section.project_id && old_section_id == section.id) {
                if (items_map.has_key (item.id)) {
                    items_map [item.id].hide_destroy ();
                    items_map.unset (item.id);
                }
            }

            if (item.project_id == section.project_id && item.section_id == section.id && !item.has_parent) {
                add_item (item);
            }

            listbox.invalidate_filter ();
        })] = Services.EventBus.get_default ();

        signals_map[section.project.sort_order_changed.connect (() => {
            update_sort ();
        })] = section.project;

        signals_map[Services.EventBus.get_default ().update_section_sort_func.connect ((project_id, section_id, value) => {
            if (section.project_id == project_id && section.id == section_id) {
                if (value) {
                    update_sort ();
                } else {
                    listbox.set_sort_func (null);
                }
            }
        })] = Services.EventBus.get_default ();

        signals_map[section.section_count_updated.connect (() => {
            // count_label.label = section.section_count.to_string ();
            // count_revealer.reveal_child = int.parse (count_label.label) > 0;
        })] = section;

        signals_map[add_button.clicked.connect (() => {
            prepare_new_item ();
        })] = add_button;

        signals_map[Services.EventBus.get_default ().update_inserted_item_map.connect ((_row, old_section_id) => {
            if (_row is Layouts.ItemBoard) {
                var row = (Layouts.ItemBoard) _row;

                if (row.item.project_id == section.project_id && row.item.section_id == section.id) {
                    if (!items_map.has_key (row.item.id)) {
                        items_map [row.item.id] = row;
                        update_sort ();
                    }
                }
                
                // vala-lint=no-space
                if (row.item.project_id == section.project_id && row.item.section_id != section.id && old_section_id == section.id) {
                    if (items_map.has_key (row.item.id)) {
                        items_map.unset (row.item.id);
                    }
                }
            }
        })] = Services.EventBus.get_default ();

        signals_map[section.project.filter_added.connect (() => {
            listbox.invalidate_filter ();
        })] = section.project;

        signals_map[section.project.filter_removed.connect (() => {
            listbox.invalidate_filter ();
        })] = section.project;

        signals_map[section.project.filter_updated.connect (() => {
            listbox.invalidate_filter ();
        })] = section.project;

        signals_map[section.sensitive_change.connect (() => {
            sensitive = section.sensitive;
        })] = section;

        signals_map[section.loading_change.connect (() => {
            is_loading = section.loading;
        })] = section;
    }

    private void update_request () {
        name_label.label = section.name;
        description_label.label = section.description.strip ();
        description_revealer.reveal_child = description_label.label.length > 0;
        Util.get_default ().set_widget_color (Util.get_default ().get_color (section.color), widget_color);
    }

    private void update_count_label (int count) {
        count_label.label = count <= 0 ? "" : count.to_string ();
    }

    public void add_items () {
        items_map.clear ();
        
        foreach (Objects.Item item in is_inbox_section ? section.project.items : section.items) {
            add_item (item);
        }

        update_sort ();
    }

    private void update_sort () {
        if (section.project.sort_order == 0) {
            listbox.set_sort_func (null);
        } else {
            listbox.set_sort_func (set_sort_func);
        }

        listbox.invalidate_filter ();
    }

    private int set_sort_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow lbbefore) {
        Objects.Item item1 = ((Layouts.ItemBoard) lbrow).item;
        Objects.Item item2 = ((Layouts.ItemBoard) lbbefore).item;
        
        if (section.project.sort_order == 1) {
            return item1.content.collate (item2.content);
        }
        
        if (section.project.sort_order == 2) {
            if (item1.has_due && item2.has_due) {
                var date1 = item1.due.datetime;
                var date2 = item2.due.datetime;

                return date1.compare (date2);
            }

            if (!item1.has_due && item2.has_due) {
                return 1;
            }

            return 0;
        }
        
        if (section.project.sort_order == 3) {
            return item1.added_datetime.compare (item2.added_datetime);
        }
        
        if (section.project.sort_order == 4) {
            if (item1.priority < item2.priority) {
                return 1;
            }

            if (item1.priority < item2.priority) {
                return -1;
            }

            return 0;
        }

        return 0;
    }

    public void add_item (Objects.Item item, int position = -1) {
        if (item.checked) {
            return;
        }

        if (item.pinned) {
			return;
		}

        if (items_map.has_key (item.id)) {
            return;
        }

        items_map [item.id] = new Layouts.ItemBoard (item);
            
        if (item.custom_order) {
            listbox.insert (items_map [item.id], item.child_order);
        } else {
            listbox.append (items_map [item.id]);
        }

        update_count_label (section_count);
    }

    private Gtk.Popover build_context_menu () {
        var add_item = new Widgets.ContextMenu.MenuItem (_("Add Task"), "plus-large-symbolic");
        var edit_item = new Widgets.ContextMenu.MenuItem (_("Edit Section"), "edit-symbolic");
        var move_item = new Widgets.ContextMenu.MenuItem (_("Move Section"), "arrow3-right-symbolic");
        var manage_item = new Widgets.ContextMenu.MenuItem (_("Manage Section Order"), "view-list-ordered-symbolic");
        var duplicate_item = new Widgets.ContextMenu.MenuItem (_("Duplicate"), "tabs-stack-symbolic");
		var show_completed_item = new Widgets.ContextMenu.MenuItem (_("Show Completed Tasks"), "check-round-outline-symbolic");

        var archive_item = new Widgets.ContextMenu.MenuItem (_("Archive"), "shoe-box-symbolic");
        var delete_item = new Widgets.ContextMenu.MenuItem (_("Delete Section"), "user-trash-symbolic");
        delete_item.add_css_class ("menu-item-danger");
        
        var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        menu_box.margin_top = menu_box.margin_bottom = 3;
        menu_box.append (add_item);

        if (!is_inbox_section) {
            menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
            menu_box.append (edit_item);
            menu_box.append (move_item);
            menu_box.append (manage_item);
            menu_box.append (duplicate_item);
            menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
		    menu_box.append (show_completed_item);
            menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
            menu_box.append (archive_item);
            menu_box.append (delete_item);
        } else {
            menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
            menu_box.append (show_completed_item);
            menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
            menu_box.append (manage_item);
        }

        var menu_popover = new Gtk.Popover () {
            has_arrow = false,
            child = menu_box,
            position = Gtk.PositionType.BOTTOM,
            width_request = 250
        };

        add_item.clicked.connect (() => {
            menu_popover.popdown ();
            prepare_new_item ();
        });

        edit_item.clicked.connect (() => {
            menu_popover.popdown ();

            var dialog = new Dialogs.Section (section);
			dialog.present (Planify._instance.main_window);
        });

        move_item.clicked.connect (() => {
            menu_popover.popdown ();

            var dialog = new Dialogs.ProjectPicker.ProjectPicker.for_project (section.source);
            dialog.project = section.project;
            dialog.present (Planify._instance.main_window);

            dialog.changed.connect ((type, id) => {
                if (type == "project") {
                    move_section (id);
                }
            });
        });

        manage_item.clicked.connect (() => {
            menu_popover.popdown ();
            
            var dialog = new Dialogs.ManageSectionOrder (section.project);
            dialog.present (Planify._instance.main_window);
        });

        archive_item.clicked.connect (() => {
			menu_popover.popdown ();
			section.archive_section ((Gtk.Window) Planify.instance.main_window);
		});

        delete_item.clicked.connect (() => {
            menu_popover.popdown ();

            var dialog = new Adw.AlertDialog (
			    _("Delete Section %s".printf (section.name)),
				_("This can not be undone")
			);

            dialog.add_response ("cancel", _("Cancel"));
            dialog.add_response ("delete", _("Delete"));
            dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.present (Planify._instance.main_window);

            dialog.response.connect ((response) => {
                if (response == "delete") {
                    is_loading = true;

                    if (section.project.source_type == SourceType.TODOIST) {
                        Services.Todoist.get_default ().delete.begin (section, (obj, res) => {
                            Services.Todoist.get_default ().delete.end (res);
                            Services.Store.instance ().delete_section (section);
                        });
                    } else {
                        Services.Store.instance ().delete_section (section);
                    }
                }
            });
        });

        duplicate_item.clicked.connect (() => {
            menu_popover.popdown ();
            Util.get_default ().duplicate_section.begin (section, section.project_id);
        });

        return menu_popover;
    }

    public void prepare_new_item (string content = "") {
        var dialog = new Dialogs.QuickAdd ();
        dialog.for_base_object (section);
        dialog.update_content (content);
        dialog.present (Planify._instance.main_window);
    }

    private void move_section (string project_id) {
        string old_section_id = section.project_id;
        section.project_id = project_id;

        if (section.project.source_type == SourceType.TODOIST) {
            is_loading = true;

            Services.Todoist.get_default ().move_project_section.begin (section, project_id, (obj, res) => {
                if (Services.Todoist.get_default ().move_project_section.end (res).status) {
                    Services.Store.instance ().move_section (section, old_section_id);
                    is_loading = false;
                }
            });
        } else if (section.project.source_type == SourceType.LOCAL) {
            Services.Store.instance ().move_section (section, project_id);
            is_loading = false;
        }
    }

    private void build_drag_and_drop () {
        // Drop
        build_drop_target ();
    }

    private void build_drop_target () {
        var drop_target = new Gtk.DropTarget (typeof (Layouts.ItemBoard), Gdk.DragAction.MOVE);
        content_box.add_controller (drop_target);
        signals_map[drop_target.drop.connect ((value, x, y) => {
            var picked_widget = (Layouts.ItemBoard) value;

			picked_widget.drag_end ();

			string old_section_id = picked_widget.item.section_id;
			string old_parent_id = picked_widget.item.parent_id;

			picked_widget.item.project_id = section.project_id;
			picked_widget.item.section_id = section.id;
            picked_widget.item.parent_id = "";

			if (picked_widget.item.project.source_type == SourceType.TODOIST) {
				string type = "section_id";
				string id = section.id;

				if (is_inbox_section) {
					type = "project_id";
					id = section.project_id;
				}

				Services.Todoist.get_default ().move_item.begin (picked_widget.item, type, id, (obj, res) => {
					if (Services.Todoist.get_default ().move_item.end (res).status) {
						Services.Store.instance ().update_item (picked_widget.item);
					}
				});
			} else if (picked_widget.item.project.source_type == SourceType.LOCAL) {
				Services.Store.instance ().update_item (picked_widget.item);
			}

			var source_list = (Gtk.ListBox) picked_widget.parent;
			source_list.remove (picked_widget);

			listbox.append (picked_widget);
			Services.EventBus.get_default ().update_inserted_item_map (picked_widget, old_section_id, old_parent_id);
            update_items_item_order (listbox);

			return true;
        })] = drop_target;
    }

    private void update_items_item_order (Gtk.ListBox listbox) {
		unowned Layouts.ItemBoard? item_row = null;
		var row_index = 0;

		do {
			item_row = (Layouts.ItemBoard) listbox.get_row_at_index (row_index);

			if (item_row != null) {
				item_row.item.child_order = row_index;
				Services.Store.instance ().update_item (item_row.item);
			}

			row_index++;
		} while (item_row != null);
	}

    public void hide_destroy () {
        visible = false;
        clean_up ();
        Timeout.add (225, () => {
            ((Gtk.FlowBox) parent).remove (this);
            return GLib.Source.REMOVE;
        });
    }

    public void clean_up () {
        listbox.set_sort_func (null);
        listbox.set_filter_func (null);

        // Remove Items
        foreach (unowned Gtk.Widget child in Util.get_default ().get_children (listbox) ) {
            ((Layouts.ItemBoard) child).hide_destroy ();
        }

        // Clean Signals
        foreach (var entry in signals_map.entries) {
            entry.value.disconnect (entry.key);
        }
        
        signals_map.clear ();
    }
}
