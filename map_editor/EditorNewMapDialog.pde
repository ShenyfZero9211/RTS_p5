import java.awt.BorderLayout;
import java.awt.GridLayout;
import javax.swing.JCheckBox;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;

/**
 * Swing dialog for width / height (+ optional flag) when creating a new map.
 * Tile size is fixed (matches RTS_p5/data maps and {@link EditorState#initDefaults} default).
 */
class EditorNewMapDialog {
  static final int FIXED_TILE_SIZE_PX = 40;

  boolean showAndApply(EditorState s) {
    JTextField wf = new JTextField(String.valueOf(s.mapWidth), 6);
    JTextField hf = new JTextField(String.valueOf(s.mapHeight), 6);
    JCheckBox obs = new JCheckBox("Disable static obstacles", s.disableStaticObstacles);
    JCheckBox test = new JCheckBox("\u8bbe\u7f6e\u4e3a\u6d4b\u8bd5\u5730\u56fe\uff08\u5f15\u64ce\u81ea\u52a8\u521d\u59cb\u5316\u57fa\u5730\u7b49\uff09", s.testMap);

    JPanel grid = new JPanel(new GridLayout(2, 2, 8, 6));
    grid.add(new JLabel("Width (tiles):"));
    grid.add(wf);
    grid.add(new JLabel("Height (tiles):"));
    grid.add(hf);

    JPanel south = new JPanel(new GridLayout(2, 1, 0, 4));
    south.add(obs);
    south.add(test);

    JPanel root = new JPanel(new BorderLayout(0, 8));
    root.add(grid, BorderLayout.NORTH);
    root.add(south, BorderLayout.SOUTH);

    int r = JOptionPane.showConfirmDialog(null, root, "New map", JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
    if (r != JOptionPane.OK_OPTION) {
      return false;
    }
    try {
      int w = Integer.parseInt(wf.getText().trim());
      int h = Integer.parseInt(hf.getText().trim());
      w = constrain(w, 8, 512);
      h = constrain(h, 8, 512);
      s.initDefaults(w, h, FIXED_TILE_SIZE_PX);
      s.disableStaticObstacles = obs.isSelected();
      s.testMap = test.isSelected();
      return true;
    }
    catch (NumberFormatException e) {
      s.setStatus("New map: invalid numbers.");
      return false;
    }
  }
}
