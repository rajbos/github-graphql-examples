function RunQuery {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$query,
        [Parameter(Mandatory=$false)]
        [boolean]$oldId = $false
    )

    if ($oldId) {
        $headerValue = 0
    }
    else {
        $headerValue = 1
    }

    $response = $(gh api graphql -H "X-Github-Next-Global-ID: $headerValue" -F query=$query | ConvertFrom-Json)
    return $response.data
}

function GetLoginId-Old {
    # get user account
    $query = "query { viewer { login, id }}"
    $response = RunQuery -query $query -oldId $true
    $id = $response.viewer.id
    $login = $response.viewer.login

    Write-Host "Found user [$login] with old id [$userId]"
    return $id
}

function GetLoginId-New {
    # get user account
    $query = "query { viewer { login, id }}"
    $response = RunQuery -query $query -oldId $false
    $id = $response.viewer.id
    $login = $response.viewer.login

    Write-Host "Found user [$login] with new id [$userId]"
    return $id
}

function ConvertOldIdToNew {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$oldId
    )
    $query = "query search { node(id: ""$oldId"") { id } }"
    $response = RunQuery -query $query
    $newId = $response.node.id
    Write-Host "Found new login Id: [$newId]"

    return $newId
}

function New-Project {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$title,
        [Parameter(Mandatory=$true)]
        [string]$ownerId
    )
    $query="mutation (`$ownerId: ID!, `$title: String!) { createProjectV2(input: { ownerId: `$ownerId, title: `$title }) { projectV2 { id } } }"
    $response = $(gh api graphql -f ownerId=$ownerId -f title=$title -F query=$query | ConvertFrom-Json)
    return $response.data
}

function GetOrganizationId {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$organizationName
    )
    $query="query { organization(login: ""$organizationName"") { id, name } }"
    $response = $(gh api graphql -F query=$query | ConvertFrom-Json)
    return $response.data
}

function GetProjectsInOrg {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$organizationName
    )
    $query="query { organization(login: ""$organizationName"") { projectsV2(first: 100) { edges { node { id } } } } }"
    $response = $(gh api graphql -F query=$query | ConvertFrom-Json)
    return $response.data
}

# login if needed, but make sure you are using the right scope for projectsV2
#gh auth login --scopes "project"

# get old id and then convert to new id
$id = GetLoginId-Old
$newId = ConvertOldIdToNew -oldId $id

# get new id in one call
$id = GetLoginId-New
Write-Host "Found new login id: [$id]"

# create a project for the login id
#$newProject = $(New-Project -title "Test Project" -ownerId $id)
#Write-Host "Created project with id: [$($newProject.createProjectV2.projectV2.id)]"

# get projects for an org
$organizationName = "robs-tests"
$projects = $(GetProjectsInOrg -organizationName $organizationName)
Write-Host "Found $($projects.organization.projectsV2.edges.count) existing projects in organization [$organizationName]"

# get org id
$organization = GetOrganizationId -organizationName $organizationName
Write-Host "Found organization [$($organization.organization.name)] with id [$($organization.organization.id)]"

# create a project for the organization id
#$newProject = $(New-Project -title "Test Project" -ownerId $organization.organization.id)
#Write-Host "Created project with id: [$($newProject.createProjectV2.projectV2.id)] in organization [$($organization.organization.name)]"
