// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleTodo — personal task manager
/// @notice Covers: struct, mapping, modifier with params, for loop, delete, view

contract SimpleTodo {
    struct Task {
        string task;
        string description;
        bool completed;
        address owner; // ← ADDED: to track whose task it is
    }

    Task[] public tasks;

    mapping(address => uint) public taskCount;

    // Modifier: only the task owner can call
    modifier onlyTaskOwner(uint _taskId) {
        require(_taskId < tasks.length, "Task does not exist");
        require(msg.sender == tasks[_taskId].owner, "Not your task");
        _;
    }

    // Create a new task
    function createTask(
        string memory _task,
        string memory _description
    ) external {
        tasks.push(Task(_task, _description, false, msg.sender));
        taskCount[msg.sender]++;
    }

    // Delete a task
    function deleteTask(uint _taskId) external onlyTaskOwner(_taskId) {
        delete tasks[_taskId];
        taskCount[msg.sender]--;
    }

    // Change task name
    function changeTaskName(
        uint _taskId,
        string calldata _newName
    ) external onlyTaskOwner(_taskId) {
        tasks[_taskId].task = _newName;
    }

    // Change task description
    function changeDescription(
        uint _taskId,
        string calldata _newDescription
    ) external onlyTaskOwner(_taskId) {
        tasks[_taskId].description = _newDescription;
    }

    // Mark task as completed
    function completeTask(uint _taskId) external onlyTaskOwner(_taskId) {
        tasks[_taskId].completed = true;
    }

    // Get your task IDs (no gas — view function)
    function getMyTasks() external view returns (uint[] memory) {
        uint[] memory result = new uint[](taskCount[msg.sender]);
        uint counter = 0;

        for (uint i = 0; i < tasks.length; i++) {
            if (tasks[i].owner == msg.sender) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    // Get total task count
    function getTotalTasks() external view returns (uint) {
        return tasks.length;
    }

    // Get your task count
    function getMyTaskCount() external view returns (uint) {
        return taskCount[msg.sender];
    }
}
