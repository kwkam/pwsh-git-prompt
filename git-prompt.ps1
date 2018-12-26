# pwsh git prompt support
# vi: ts=2 sw=2
#
# A clone of git-prompt.sh from:
# https://github.com/git/git/tree/master/contrib/completion
#
# This script allows you to see repository status in your prompt.
#
# To enable:
#
#    1) Copy this file to where profile.ps1 is located. e.g.
#        $(Split-Path -Parent $PROFILE)/git-prompt.ps1
#    2) Add the following line to your profile.ps1:
#        . $PSScriptRoot/git-prompt.ps1
#    3a) Change your prompt function to call __git_prompt as
#        command-substitution:
#          function Prompt
#          {
#            $u = [Environment]::UserName
#            $h = [Environment]::MachineName
#            $w = $PWD.Path.Replace($HOME, '~')
#            "PS $u@$h $w $(__git_prompt -f '({0})')`n$NestedPromptLevel> "
#          }
#        the optional argument will be used as format string.
#    3b) Alternatively, __git_prompt can be used for prompt function
#        with two parameters, <prep> and <post>, which are strings
#        you would put in prompt before and after the status string
#        generated by the git-prompt machinery. e.g.
#          function Prompt
#          {
#            $u = [Environment]::UserName
#            $h = [Environment]::MachineName
#            $w = $PWD.Path.Replace($HOME, '~')
#            __git_prompt "PS `e[0;33m$u@$h`e[m:`e[0;36m$w`e[m" `
#                         "`n$NestedPromptLevel> "
#          }
#          will show username, at-sign, host, colon, cwd, then
#          various status string, followed by digit, GT and SP, as
#          your prompt.
#        Optionally, you can supply a third argument with a .NET
#        format string to finetune the output of the branch status
#
# The repository status will be displayed only if you are currently in a
# git repository. The %s token is the placeholder for the shown status.
#
# The prompt status always includes the current branch name.
#
# In addition, if you set GIT_PS1.SHOWDIRTYSTATE to a nonempty value,
# unstaged (*) and staged (+) changes will be shown next to the branch
# name.  You can configure this per-repository with the
# bash.showDirtyState variable, which defaults to true once
# GIT_PS1.SHOWDIRTYSTATE is enabled.
#
# You can also see if currently something is stashed, by setting
# GIT_PS1.SHOWSTASHSTATE to a nonempty value. If something is stashed,
# then a '$' will be shown next to the branch name.
#
# If you would like to see if there're untracked files, then you can set
# GIT_PS1.SHOWUNTRACKEDFILES to a nonempty value. If there're untracked
# files, then a '%' will be shown next to the branch name.  You can
# configure this per-repository with the bash.showUntrackedFiles
# variable, which defaults to true once GIT_PS1.SHOWUNTRACKEDFILES is
# enabled.
#
# If you would like to see the difference between HEAD and its upstream,
# set GIT_PS1.SHOWUPSTREAM.ENABLE.  A "<" indicates you are behind, ">"
# indicates you are ahead, "<>" indicates you have diverged and "="
# indicates that there is no difference. You can further control
# behaviour by setting GIT_PS1.SHOWUPSTREAM to an associative array
# of values:
#
#     ENABLE        show difference to upstream
#     VERBOSE       show number of commits ahead/behind (+/-) upstream
#     NAME          if verbose, then also show the upstream abbrev name
#
# You can change the separator between the branch name and the above
# state symbols by setting GIT_PS1.STATESEPARATOR. The default separator
# is SP.
#
# If you would like to see more information about the identity of
# commits checked out as a detached HEAD, set GIT_PS1.DESCRIBE_STYLE
# to one of these values:
#
#     contains      relative to newer annotated tag (v1.6.3.2~35)
#     branch        relative to newer tag or branch (master~4)
#     describe      relative to older annotated tag (v1.6.3.1-13-gdd42c2f)
#     tag           relative to any older tag (v1.6.3.1-13-gdd42c2f)
#     default       exactly matching tag
#
# If you would like a colored hint about the current dirty state, set
# GIT_PS1.SHOWCOLORHINTS to a nonempty value. The colors are based on
# the colored output of "git status -sb" and are available only when
# using __git_prompt with <prep> and <post>.
#
# If you would like __git_prompt to do nothing in the case when the current
# directory is set up to be ignored by git, then set
# GIT_PS1.HIDE_IF_PWD_IGNORED to a nonempty value. Override this on the
# repository level by setting bash.hideIfPwdIgnored to "false".

$GIT_PS1 = @{
	DESCRIBE_STYLE = 'default'
	SHOWDIRTYSTATE = $false
	SHOWSTASHSTATE = $false
	SHOWUNTRACKEDFILES = $false
	SHOWUPSTREAM = @{
		ENABLE  = $false
		VERBOSE = $false
		NAME    = $false
	}
	SHOWCOLORHINTS = $false
	PALETTE = @{
		BAD   = '31'
		OK    = '32'
		FLAGS = '1;34'
		TEXT  = '1;30'
	}
}

function __git_prompt
{
	param (
		[string] $prep,
		[string] $post,
		[string] $format = ' ({0})',
		[hashtable] $opts = $GIT_PS1
	)

	$info = @{}

	function __git
	{
		git @args
	}

	function __git_ps1_status {
		if (! $info.Contains('status')) {
			$branch,$fileinfo = __git status --branch --porcelain
			$info.status = @{fileinfo = @($fileinfo)}
			if ($branch -match '^## (?<cb>\S+?)(?:\.\.\.(?<ub>\S+)(?: \[(?<k1>\w+) (?<v1>\d+)(?:, (?<k2>\w+) (?<v2>\d+))?\])?)?$') {
				switch ($matches) {
					{$_.cb} {
						$info.status.branch = $_.cb
					}
					{$_.ub} {
						$info.status.upstream = @{name = $_.ub}
					}
					{$_.k1} {
						$info.status.upstream.$($_.k1) = $_.v1
					}
					{$_.k2} {
						$info.status.upstream.$($_.k2) = $_.v2
					}
				}
			}
		}
		return $info.status
	}

	function __git_ps1_symbolic_ref {
		if (! $info.Contains('ref')) {
			if ($(Get-Item -LiteralPath $gitdir/HEAD).Attributes -band [IO.FileAttributes]::ReparsePoint) {
				# symlink symbolic ref
				$info.ref = __git symbolic-ref HEAD 2> $null
			} else {
				$head = Get-Content -Head 1 -LiteralPath $gitdir/HEAD
				if (! $head) {
					return $true
				}
				# is it a symbolic ref?
				if ($head -match '^ref: (?<ref>.+)$') {
					$info.ref = $matches.ref
				}
			}
		}
	}

	# Helper function that is meant to be called from __git_ps1.  It
	# injects color codes into the appropriate gitstring variables used
	# to build a gitstring.
	function __git_ps1_colorize_gitstring
	{
		param (
			[hashtable] $palette
		)

		if ($palette.Count) {
			$c_clear      = "`e[m"
			$bad_color    = "`e[$($palette.BAD)m"
			$ok_color     = "`e[$($palette.OK)m"
			$flags_color  = "`e[$($palette.FLAGS)m"
			$text_color   = "`e[$($palette.TEXT)m"
			$branch_color = switch ($info) {
				{$info.away} {
					$text_color
					continue
				}
				{$info.detached} {
					$bad_color
					continue
				}
				default {
					$ok_color
				}
			}
		}

		$stat = [Text.StringBuilder]::new()
		if ($info.w) {
			[void] $stat.Append($bad_color).Append($info.w)
		}
		if ($info.i) {
			[void] $stat.Append($ok_color).Append($info.i)
		}
		if ($info.s) {
			[void] $stat.Append($flags_color).Append($info.s)
		}
		if ($info.u) {
			[void] $stat.Append($bad_color).Append($info.u)
		}
		$name = [Text.StringBuilder]::new($branch_color).Append($info.c).Append($info.b)
		if ($stat.Length) {
			[void] $name.Append($c_clear).Append($info.z)
		}
		if ($info.p) {
			[void] $stat.Append($text_color).Append($info.p)
		}
		if ($info.a) {
			[void] $stat.Append($ok_color).Append($info.a)
		}
		if ($info.d) {
			[void] $stat.Append($bad_color).Append($info.d)
		}
		if ($info.n) {
			[void] $stat.Append(' ').Append($flags_color).Append($info.n)
		}
		[void] $stat.Append($c_clear).Append($info.r)
		if ($info.step -and $info.total) {
			[void] $stat.Append(' ').Append($info.step).Append('/').Append($info.total)
		}

		return [string]::Concat($name, $stat)
	}

	# __git_ps1 requires 1 arguments (format string)
	# The required parameter will be used as .NET format string to further
	# customize the output of the git-status string.
	# It prints text to add to the string (includes branch name)
	# You can request colored hints using SHOWCOLORHINTS=true
	function __git_ps1
	{
		param (
			[parameter(mandatory = $true)]
			[string] $format
		)

		try {
			$repo_info = __git rev-parse --git-dir `
			                           --is-inside-git-dir `
			                           --is-bare-repository `
			                           --is-inside-work-tree `
			                           --short HEAD 2> $null
		} catch {
			return
		}

		if ($repo_info.Count -lt 4) {
			return
		}

		$gitdir             = $repo_info[0]
		$inside_gitdir      = $repo_info[1] -eq 'true'
		$bare_repo          = $repo_info[2] -eq 'true'
		$inside_worktree    = $repo_info[3] -eq 'true'
		if (! $LASTEXITCODE) {
			$info.short_sha = $repo_info[4]
		}

		if ($inside_worktree -and $opts.HIDE_IF_PWD_IGNORED) {
			__git check-ignore -q .
			if (! $LASTEXITCODE) {
				return
			}
		}

		if ($inside_gitdir) {
			if ($bare_repo) {
				$info.c = 'BARE:'
			} else {
				$info.b = 'GIT_DIR!'
			}
		} elseif ($inside_worktree) {
			if ($opts.SHOWDIRTYSTATE) {
				$status = $(__git_ps1_status).fileinfo
				switch -wildcard ($status) {
					'?[MADRCU] *' {
						$info.w = '*'
						if ($info.i) { break }
					}
					'[MADRCU]? *' {
						$info.i = '+'
						if ($info.w) { break }
					}
				}
				if (! ($info.short_sha -or $info.i)) {
					$info.i = '#'
				}
			}
			if ($opts.SHOWSTASHSTATE) {
				# FIXME code duplication
				if (Test-Path -PathType Leaf -LiteralPath $gitdir/refs/stash) {
					$info.s = '$'
				} else {
					# fallback for case that refs/stash does not exist
					__git rev-parse --verify --quiet refs/stash > $null
					if (! $LASTEXITCODE) {
						$info.s = '$!'
					}
				}
			}
			if ($opts.SHOWUNTRACKEDFILES) {
				$status = $(__git_ps1_status).fileinfo
				if ($status -and $status[-1] -like '`?`? *') {
					$info.u = '%'
				}
			}
			if ($opts.SHOWUPSTREAM.ENABLE) {
				$status = $(__git_ps1_status).upstream
				if ($status) {
					if ($opts.SHOWUPSTREAM.VERBOSE) {
						if ($status.ahead) {
							$info.a = "+$($status.ahead)"
						}
						if ($status.behind) {
							$info.d = "-$($status.behind)"
						}
						$info.p = if ($info.a -or $info.d) { ' u' } else { ' u=' }
						if ($opts.SHOWUPSTREAM.NAME) {
							$info.n = $status.name
						}
					} else {
						if ($status.ahead -and $status.behind) {
							$info.a,$info.d = '<','>'
						} elseif ($status.ahead) {
							$info.a = '>'
						} elseif ($status.behind) {
							$info.d = '<'
						} else {
							$info.p = '='
						}
					}
				}
			}
		}

		if (! $info.b) {
			$info.b = $(__git_ps1_status).branch
		}

		if (! $info.b) {
			if (__git_ps1_symbolic_ref) {
				return
			}
			if (! $info.ref) {
				$info.detached = $true
				$head = switch ($opts.DESCRIBE_STYLE) {
					'contains' {
						__git describe --contains HEAD
					}
					'branch' {
						__git describe --contains --all HEAD
					}
					'tag' {
						__git describe --tags HEAD
					}
					'describe' {
						__git describe HEAD
					}
					default {
						__git describe --tags --exact-match HEAD
					}
				} 2> $null
				if ($LASTEXITCODE) {
					$head = "$($info.short_sha)..."
				}
				$info.b = "($head)"
			} else {
				$info.b = $info.ref -replace '^refs/heads/', ''
			}
		}

		if (Test-Path -PathType Container -LiteralPath $gitdir/rebase-merge) {
			if (__git_ps1_symbolic_ref) {
				return
			}
			if ($(Get-Content -Head 1 -LiteralPath $gitdir/rebase-merge/head-name) -ne $info.ref) {
				$info.away = $true
			}
			$info.step  = Get-Content -Head 1 -LiteralPath $gitdir/rebase-merge/msgnum
			$info.total = Get-Content -Head 1 -LiteralPath $gitdir/rebase-merge/end
			if (Test-Path -PathType Leaf -LiteralPath $gitdir/rebase-merge/interactive) {
				$info.r = '|REBASE-i'
			} else {
				$info.r = '|REBASE-m'
			}
		} elseif (Test-Path -PathType Container -LiteralPath $gitdir/rebase-apply) {
			if (__git_ps1_symbolic_ref) {
				return
			}
			if ($(Get-Content -Head 1 -LiteralPath $gitdir/rebase-apply/head-name) -ne $info.ref) {
				$info.away = $true
			}
			$info.step  = Get-Content -Head 1 -LiteralPath $gitdir/rebase-apply/next
			$info.total = Get-Content -Head 1 -LiteralPath $gitdir/rebase-apply/last
			if (Test-Path -PathType Leaf -LiteralPath $gitdir/rebase-apply/rebasing) {
				$info.r = '|REBASE'
			} elseif (Test-Path -PathType Leaf -LiteralPath $gitdir/rebase-apply/applying) {
				$info.r = '|AM'
			} else {
				$info.r = '|AM/REBASE'
			}
		} elseif (Test-Path -PathType Leaf -LiteralPath $gitdir/MERGE_HEAD) {
			$info.r = '|MERGING'
		} elseif (Test-Path -PathType Leaf -LiteralPath $gitdir/CHERRY_PICK_HEAD) {
			$info.r = '|CHERRY-PICKING'
		} elseif (Test-Path -PathType Leaf -LiteralPath $gitdir/REVERT_HEAD) {
			$info.r = '|REVERTING'
		} elseif (Test-Path -PathType Leaf -LiteralPath $gitdir/BISECT_LOG) {
			$info.r = '|BISECTING'
		}

		$info.z = if ($opts.Contains('STATESEPARATOR')) { $opts.STATESEPARATOR } else { ' ' }

		$palette = if ($opts.SHOWCOLORHINTS) { $opts.PALETTE }
		return $format -f $(__git_ps1_colorize_gitstring $palette)
	}

	if ($prep -and $post) {
		return "$prep$(__git_ps1 $format)$post"
	}
	return __git_ps1 $format
}
