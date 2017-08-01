#! /bin/sh

# exit on error immediately
set -e

function start_module()
{
  echo "Starting YaST module '$2'..."
  # run "yast <module>" in a new tmux session (-d = detach, -s = session name)
  # force 80x25 terminal size
  tmux new-session -d -s $1 -x 80 -y 25 "yast $2"
}

function dump_screen()
{
  echo "----------------------- Screen Dump Begin -----------------------------"
  if [ "$TRAVIS" == "1" ]; then
    # the sed call transforms spaces to non-breakable UTF-8 spaces because
    # Travis does not display a normal space sequence correctly
    tmux capture-pane -e -p -t "$1" | sed 's/ /\xC2\xA0/g'
  else
    tmux capture-pane -e -p -t "$1"
  fi
  tput init
  echo "----------------------- Screen Dump End -------------------------------"
}

function expect_text()
{
  if tmux capture-pane -p -t "$1" | grep -q "$2"; then
    echo "Matched expected text: '$2'"
  else
    echo "ERROR: No match for expected text '$2'"
    exit 1
  fi
}

function not_expect_text()
{
  if tmux capture-pane -p -t "$1" | grep -q "$2"; then
    echo "ERROR: Matched unexpected text: '$2'"
    exit 1
  fi
}

function send_keys()
{
  echo "Sending keys: $2"
  tmux send-keys -t "$1" "$2"
}

function yast_exited()
{
  if tmux has-session "$1" 2> /dev/null; then
    echo "ERROR: YaST is still running!"
    exit 1
  else
    echo "YaST exited, OK"
  fi
}

function skip_unsupported()
{
  # Bootloader is not configured (does not make sense in Docker),
  # so there is a warning displayed.
  if tmux capture-pane -p -t "$SESSION" | grep -q "This system is not supported by rear"; then
    echo "Ignoring 'unsupported system' warning"
    # Press "Ignore" (Alt-i shortcut)
    send_keys $SESSION "M-i"
    sleep 3
  fi
}

# additionally install tmux
# TODO: install tmux in the shared base Docker image
zypper --non-interactive in --no-recommends tmux

# install the built package
# TODO: use zypper if the dependencies are really required:
# zypper --non-interactive in --no-recommends /usr/src/packages/RPMS/*/*.rpm
rpm -iv --force --nodeps /usr/src/packages/RPMS/*/*.rpm

# name of the tmux session
SESSION=yast2_rear


###
### Start the module and change one option
###

# run "yast rear" in a new session
start_module $SESSION rear

# wait a bit to ensure YaST is up
# TODO: wait until the screen contains the expected text (with a timeout),
# 3 seconds might not be enough on a slow or overloaded machine
sleep 3

dump_screen $SESSION
not_expect_text $SESSION "Internal error"

skip_unsupported
 
dump_screen $SESSION
expect_text $SESSION "Your ReaR configuration needs to be modified"
# Press "OK" (F10 shortcut)
send_keys $SESSION "F10"

sleep 3
dump_screen $SESSION
expect_text $SESSION "Rear Configuration"

# activate the "Boot Media" widget
send_keys $SESSION "M-b"
# select the "USB" option
send_keys $SESSION "Down"
send_keys $SESSION "Enter"

sleep 1
dump_screen $SESSION
# ensure it is selected
expect_text $SESSION "USB"
not_expect_text $SESSION "ISO"

# save the configuration
send_keys $SESSION "F10"

sleep 3
yast_exited $SESSION

###
### Start the module again and check that the change was saved properly
###

start_module $SESSION rear
# wait a bit to ensure YaST is up
sleep 3

skip_unsupported

dump_screen $SESSION
# USB should be selected as the boot medium
expect_text $SESSION "USB"
not_expect_text $SESSION "ISO"

# abort
send_keys $SESSION "F9"

sleep 3
yast_exited $SESSION


# TODO: trap the signals and do a cleanup at the end
# (kill YaST if it is still running, use tmux kill-session ?)
